import duckdb
from pathlib import Path

# Project paths
BASE_DIR = Path(__file__).resolve().parent
RAW_DIR = BASE_DIR / "Raw Data"
DB_PATH = BASE_DIR / "crm_sales.duckdb"

# Connect to DuckDB
con = duckdb.connect(str(DB_PATH))

# Load raw CSV files without modifying them
tables = {
    "raw_accounts": "accounts.csv",
    "raw_products": "products.csv",
    "raw_sales_pipeline": "sales_pipeline.csv",
    "raw_sales_teams": "sales_teams.csv",
}

for table_name, file_name in tables.items():
    file_path = RAW_DIR / file_name

    if not file_path.exists():
        raise FileNotFoundError(f"Missing file: {file_path}")

    con.execute(
        f"""
        CREATE OR REPLACE TABLE {table_name} AS
        SELECT *
        FROM read_csv_auto(?, header = true)
        """,
        [str(file_path)],
    )

    count = con.execute(
        f"SELECT COUNT(*) FROM {table_name}"
    ).fetchone()[0]

    print(f"{table_name}: {count:,} rows loaded")

con.close()

print("\nRaw data loaded successfully!")