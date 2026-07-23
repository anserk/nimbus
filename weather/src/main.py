import json
import os
import sys
from dataclasses import dataclass

import pandas as pd
import requests
import structlog
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobClient
from azure.storage.queue import QueueClient
from tenacity import (
    retry,
    retry_if_exception,
    stop_after_attempt,
    wait_random_exponential,
)


@dataclass(frozen=True)
class City:
    name: str
    lat: float
    lon: float


log = structlog.get_logger()


def should_retry(exception: BaseException):
    """Return True if the request should be retried."""
    return bool(
        isinstance(exception, requests.exceptions.HTTPError)
        and exception.response is not None
        and exception.response.status_code in (429, 500, 502, 503, 504)
    )


@retry(
    stop=stop_after_attempt(5),
    wait=wait_random_exponential(multiplier=1, min=4, max=10),
    retry=retry_if_exception(should_retry),
    reraise=True
)
def fetch_weather(
    city: str, lat: float, lon: float, start_date: str, end_date: str
) -> pd.DataFrame:
    url = "https://archive-api.open-meteo.com/v1/archive"
    params = {
        "latitude": lat,
        "longitude": lon,
        "hourly": "temperature_2m,precipitation,windspeed_10m,relativehumidity_2m",
        "start_date": start_date,
        "end_date": end_date,
        "timezone": "UTC",
    }
    r = requests.get(url, params=params)
    r.raise_for_status()
    data = r.json()["hourly"]
    df = pd.DataFrame(data)
    df["city"] = city
    df["is_rainy"] = df["precipitation"] > 0.5
    df.dropna(inplace=True)
    return df


def main() -> None:
    storage_account_name = os.environ.get("AZURE_STORAGE_ACCOUNT_NAME") or None
    queue_name = os.environ.get("QUEUE_NAME") or None
    start_date = os.environ.get("START_DATE") or "2020-01-01"
    end_date = os.environ.get("END_DATE") or "2026-06-30"
    container_name = os.environ.get("OUTPUT_CONTAINER") or "weather-output"

    if storage_account_name is None or queue_name is None:
        log.error("Missing storage acconut name or queue name")
        sys.exit(1)

    storage_account_url = f"https://{storage_account_name}.blob.core.windows.net"
    queue_account_url = f"https://{storage_account_name}.queue.core.windows.net"
    default_credential = DefaultAzureCredential()

    queue_client = QueueClient(
        queue_account_url, queue_name=queue_name, credential=default_credential
    )

    message = None
    try:
        message = queue_client.receive_messages(max_messages=1).next()
    except StopIteration:
        pass

    if message is None:
        log.info("Empty queue, nothing to do.")
        sys.exit(0)

    try:
        data = json.loads(message.content)
        city = City(name=data["city"], lat=data["lat"], lon=data["lon"])
    except (ValueError, KeyError) as e:
        log.error("poison_message", message_id=message.id, exception=str(e))
        queue_client.delete_message(message=message)
        sys.exit(0)

    blob_name = f"{city.name.replace(' ', '_')}_{start_date}_{end_date}.parquet"
    blob_client = BlobClient(
        storage_account_url,
        container_name=container_name,
        blob_name=blob_name,
        credential=default_credential,
    )

    log.info(
        "city_start",
        city=city.name,
        start_date=start_date,
        end_date=end_date,
    )

    try:
        df = fetch_weather(city.name, city.lat, city.lon, start_date, end_date)
        parquet_bytes = df.to_parquet(index=True)

        blob_client.upload_blob(parquet_bytes, overwrite=True)

        queue_client.delete_message(message=message)

        log.info("city_complete", city=city.name, rows=len(df))

        sys.exit(0)

    except Exception as e:
        log.exception("etl_failed", error=str(e))
        sys.exit(1)


if __name__ == "__main__":
    main()
