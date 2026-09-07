ingest:
	.venv/bin/python ingest/ingest.py

build:
	.venv/bin/dbt build

explorar-duckdb:
	.venv/bin/python scripts/explorar.py

all: ingest build

.PHONY: ingest build explorar-duckdb all