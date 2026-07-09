import os
import sys

import pandas as pd
import requests
import structlog
from azure.storage.blob import BlobServiceClient

log = structlog.get_logger()


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
    cities = {
        "Chicago": (41.85, -87.65),
        "New York": (40.71, -74.01),
        "Los Angeles": (34.05, -118.24),
        "Atlanta": (33.75, -84.39),
    }

    start_date = os.environ.get("START_DATE") or "2020-01-01"
    end_date = os.environ.get("END_DATE") or "2026-06-30"
    conn_str = os.environ.get("AZURE_STORAGE_CONNECTION_STRING")
    container_name = os.environ.get("OUTPUT_CONTAINER") or "weather-output"

    if not conn_str:
        log.error("missing_env_var", var="AZURE_STORAGE_CONNECTION_STRING")
        sys.exit(1)

    log.info(
        "etl_start",
        cities=list(cities.keys()),
        start_date=start_date,
        end_date=end_date,
    )

    try:
        client = BlobServiceClient.from_connection_string(conn_str)

        container_client = client.get_container_client(container_name)
        if not container_client.exists():
            container_client.create_container()
            log.info("container_created", container=container_name)

        total_rows = 0

        for city, (lat, lon) in cities.items():
            log.info("city_start", city=city)

            df = fetch_weather(city, lat, lon, start_date, end_date)
            parquet_bytes = df.to_parquet(index=True)

            blob_name = f"{city.replace(' ', '_')}_{start_date}_{end_date}.parquet"
            container_client.get_blob_client(blob=blob_name).upload_blob(
                parquet_bytes, overwrite=True
            )

            log.info("city_complete", city=city, rows=len(df))
            total_rows += len(df)

        log.info("etl_complete", total_rows=total_rows)
        sys.exit(0)

    except Exception as e:
        log.exception("etl_failed", error=str(e))
        sys.exit(1)


if __name__ == "__main__":
    main()
