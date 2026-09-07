"""Abre a interface web do DuckDB para explorar o dev.duckdb.

A conexão é read-only de propósito: você pode deixar a UI aberta enquanto
roda `make ingest` / `make build`, sem dar erro de banco travado (o DuckDB
só permite um processo escrevendo por vez).

Uso:
    .venv/bin/python scripts/explorar.py

Abre http://localhost:4213 no navegador. Ctrl+C no terminal encerra.
"""

import duckdb

con = duckdb.connect("dev.duckdb")
con.execute("CALL start_ui()")

print("DuckDB UI em  http://localhost:4213 \n")
try:
    input("Enter ou Ctrl+C para encerrar...\n")
except KeyboardInterrupt:
    pass
