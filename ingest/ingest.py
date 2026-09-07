import duckdb
from pathlib import Path

RAW_DIR = Path("data/raw")
DB = "dev.duckdb"

ARQUIVOS = {
    "orders": "olist_orders_dataset.csv",
    "customers": "olist_customers_dataset.csv",
    "geolocation": "olist_geolocation_dataset.csv",
    "order_items": "olist_order_items_dataset.csv",
    "order_payments": "olist_order_payments_dataset.csv",
    "order_reviews": "olist_order_reviews_dataset.csv",
    "products": "olist_products_dataset.csv",
    "sellers": "olist_sellers_dataset.csv",
    "product_category_name_translation": "product_category_name_translation.csv"
}

# ? é placeholder do DuckDB — ele cuida das aspas e do escape. 

def main():
    con = duckdb.connect(DB)
    con.sql("CREATE SCHEMA IF NOT EXISTS raw;")
    for table, arquivo in ARQUIVOS.items():
        caminho_arquivo = RAW_DIR / arquivo
        con.execute(f"""
            CREATE OR REPLACE TABLE raw.{table} AS
            SELECT *, current_timestamp AS _loaded_at, ? as _source_file FROM 
            read_csv_auto(?)""", [arquivo, str(caminho_arquivo)])
        print(f"Arquivo {arquivo} carregado com sucesso na tabela raw.{table}.")
        n = con.sql(f"SELECT COUNT(*) FROM raw.{table}").fetchone()[0]
        print(f"raw.{table}: {n:_} linhas <- {arquivo}")
    con.close()

if __name__ == "__main__":
    main()