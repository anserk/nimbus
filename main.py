import os
import sys

import pandas as pd
import requests
import structlog

log = structlog.get_logger()


def fetch_weather(city, lat, lon, start_date, end_date):
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


def main():
    cities = {
        "Chicago": (41.85, -87.65),
        "New York": (40.71, -74.01),
        "Los Angeles": (34.05, -118.24),
        "Atlanta": (33.75, -84.39),
    }

    start_date = os.environ.get("START_DATE", "2020-01-01")
    end_date = os.environ.get("END_DATE", "2026-06-30")

    log.info(
        "etl_start",
        cities=list(cities.keys()),
        start_date=start_date,
        end_date=end_date,
    )

    try:
        total_rows = 0

        for city, (lat, lon) in cities.items():
            log.info("city_start", city=city)

            df = fetch_weather(city, lat, lon, start_date, end_date)
            df.to_parquet(f"{city.replace(' ', '_')}.parquet", index=False)

            log.info("city_complete", city=city, rows=len(df))
            total_rows += len(df)

        log.info("etl_complete", total_rows=total_rows)
        sys.exit(0)

    except Exception as e:
        log.exception("etl_failed", error=str(e))
        sys.exit(1)


if __name__ == "__main__":
    main()
