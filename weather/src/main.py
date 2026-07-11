import json
import os
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import List

import pandas as pd
import requests
import structlog
from azure.storage.blob import BlobServiceClient


@dataclass(frozen=True)
class City:
    name: str
    lat: float
    lon: float


log = structlog.get_logger()

CITY_COORDS = json.loads(Path(__file__).parent.joinpath("cities.json").read_text())


def parse_cities(cities_raw: str) -> List[City]:
    names = [c.strip() for c in cities_raw.split(",") if c.strip()]
    if not names:
        log.error("empty_city_list")
        sys.exit(1)
    missing = [n for n in names if n not in CITY_COORDS]
    if missing:
        log.error("unknown_cities", cities=missing, known=len(CITY_COORDS))
        sys.exit(1)

    # Splat upacks tuple in order, so lat lon,
    # matches the json file content.
    cities = [City(n, *CITY_COORDS[n]) for n in names]

    return cities


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

    start_date = os.environ.get("START_DATE") or "2020-01-01"
    end_date = os.environ.get("END_DATE") or "2026-06-30"
    conn_str = os.environ.get("AZURE_STORAGE_CONNECTION_STRING")
    container_name = os.environ.get("OUTPUT_CONTAINER") or "weather-output"
    cities_raw = os.environ.get("CITIES")

    if not cities_raw:
        log.error("missing_env_var", var="CITIES")
        sys.exit(1)
    if not conn_str:
        log.error("missing_env_var", var="AZURE_STORAGE_CONNECTION_STRING")
        sys.exit(1)

    cities = parse_cities(cities_raw)

    log.info(
        "etl_start",
        cities=[c.name for c in cities],
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

        for city in cities:
            log.info("city_start", city=city.name)

            df = fetch_weather(city.name, city.lat, city.lon, start_date, end_date)
            parquet_bytes = df.to_parquet(index=True)

            blob_name = f"{city.name.replace(' ', '_')}_{start_date}_{end_date}.parquet"
            container_client.get_blob_client(blob=blob_name).upload_blob(
                parquet_bytes, overwrite=True
            )

            log.info("city_complete", city=city.name, rows=len(df))
            total_rows += len(df)

        log.info("etl_complete", total_rows=total_rows)
        sys.exit(0)

    except Exception as e:
        log.exception("etl_failed", error=str(e))
        sys.exit(1)


if __name__ == "__main__":
    main()
