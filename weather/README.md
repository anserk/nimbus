# Nimbus — Weather ETL

Fetches historical hourly weather data from [Open-Meteo](https://open-meteo.com/) and writes parquet files to Azure Blob Storage. Runs as an Azure Container Apps Job.

## Setup

```bash
uv sync
```

## Environment variables

| Variable | Description | Default |
|---|---|---|
| `AZURE_STORAGE_CONNECTION_STRING` | Blob Storage connection string | required |
| `START_DATE` | Start date for weather data (`YYYY-MM-DD`) | `2020-01-01` |
| `END_DATE` | End date for weather data (`YYYY-MM-DD`) | `2026-06-30` |

## Run locally

```bash
cp .env.example .env
# fill in your connection string
uv run src/main.py
```

## Run with Docker

```bash
docker compose up
```

## Output

Parquet files written to blob storage under `weather/{end_date}/{city}.parquet`.

## Cities

Chicago, New York, Los Angeles, Atlanta. Add more in `src/main.py`.
