"""
Description:
Connects to InterSystems Cache via ODBC, fetches all base tables,
and writes each table to a Databricks Unity Catalog (<catalog>.<schema>).
Note: exports empty tables as well to preserve the structure.
"""

import pyodbc
from databricks import sql as databricks_sql
from databricks.sdk.core import Config
from dotenv import load_dotenv
import os
import sys

# variables
load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))
DRIVER = os.getenv("DRIVER")
SERVER = os.getenv("SERVER")
PORT = os.getenv("PORT")
DATABASE = os.getenv("DATABASE")
UID = os.getenv("UID")
PWD = os.getenv("PWD")

DATABRICKS_PROFILE = os.getenv("DATABRICKS_PROFILE", "dev")
DATABRICKS_HTTP_PATH = os.getenv("DATABRICKS_HTTP_PATH")
CATALOG = os.getenv("CATALOG")
SCHEMA = os.getenv("SCHEMA")

CHUNK_SIZE = 10000

# Mapping from ODBC type codes to Databricks SQL types
ODBC_TYPE_MAP = {
    pyodbc.SQL_CHAR: "STRING",
    pyodbc.SQL_VARCHAR: "STRING",
    pyodbc.SQL_LONGVARCHAR: "STRING",
    pyodbc.SQL_WCHAR: "STRING",
    pyodbc.SQL_WVARCHAR: "STRING",
    pyodbc.SQL_WLONGVARCHAR: "STRING",
    pyodbc.SQL_DECIMAL: "DECIMAL(38,10)",
    pyodbc.SQL_NUMERIC: "DECIMAL(38,10)",
    pyodbc.SQL_SMALLINT: "INT",
    pyodbc.SQL_INTEGER: "BIGINT",
    pyodbc.SQL_REAL: "FLOAT",
    pyodbc.SQL_FLOAT: "DOUBLE",
    pyodbc.SQL_DOUBLE: "DOUBLE",
    pyodbc.SQL_BIT: "BOOLEAN",
    pyodbc.SQL_TINYINT: "INT",
    pyodbc.SQL_BIGINT: "BIGINT",
    pyodbc.SQL_TYPE_DATE: "DATE",
    pyodbc.SQL_TYPE_TIME: "STRING",
    pyodbc.SQL_TYPE_TIMESTAMP: "TIMESTAMP",
}


def get_databricks_type(type_code):
    """Map an ODBC type code to a Databricks SQL type."""
    return ODBC_TYPE_MAP.get(type_code, "STRING")


def build_create_table_sql(full_table_name, columns):
    """Build a CREATE OR REPLACE TABLE statement from ODBC column descriptions."""
    col_defs = []
    for col in columns:
        col_name = col[0]
        col_type = get_databricks_type(col[1])
        col_defs.append(f"`{col_name}` {col_type}")
    cols_sql = ",\n  ".join(col_defs)
    return f"CREATE OR REPLACE TABLE {full_table_name} (\n  {cols_sql}\n)"


def escape_value(value):
    """Escape a value for inline SQL insertion."""
    if value is None:
        return "NULL"
    if isinstance(value, bytes):
        value = value.decode("utf-8", errors="replace")
    else:
        value = str(value)
    escaped = value.replace("\\", "\\\\").replace("'", "''")
    return f"'{escaped}'"


def build_insert_sql(full_table_name, rows):
    """Build an INSERT statement with inline values for a batch of rows."""
    value_tuples = []
    for row in rows:
        vals = ", ".join(escape_value(v) for v in row)
        value_tuples.append(f"({vals})")
    all_values = ",\n".join(value_tuples)
    return f"INSERT INTO {full_table_name} VALUES\n{all_values}"


def sanitise_value(value):
    """Convert values to types compatible with the Databricks SQL connector."""
    if value is None:
        return None
    if isinstance(value, bytes):
        return value.decode("utf-8", errors="replace")
    return str(value)


def main():

    # Connect to Cache via ODBC
    try:
        conn = pyodbc.connect(
            f"DRIVER={{{DRIVER}}};SERVER={SERVER};PORT={PORT};DATABASE={DATABASE};UID={UID};PWD={PWD}"
        )
        to_str = lambda v: v.decode("utf-8", errors="replace") if v is not None else None
        conn.add_output_converter(pyodbc.SQL_TYPE_DATE, to_str)
        conn.add_output_converter(pyodbc.SQL_TYPE_TIME, to_str)
        conn.add_output_converter(pyodbc.SQL_TYPE_TIMESTAMP, to_str)
        conn.add_output_converter(pyodbc.SQL_NUMERIC, to_str)
        conn.add_output_converter(pyodbc.SQL_DECIMAL, to_str)
        print("Connected to Cache!\n")
    except pyodbc.Error as e:
        print(f"Cache connection failed: {e}")
        sys.exit(1)

    # Connect to Databricks via SQL connector
    try:
        cfg = Config(profile=DATABRICKS_PROFILE)
        databricks_conn = databricks_sql.connect(
            server_hostname=cfg.host.replace("https://", ""),
            http_path=DATABRICKS_HTTP_PATH,
            credentials_provider=lambda: cfg.authenticate,
        )
        print("Connected to Databricks!\n")
    except Exception as e:
        print(f"Databricks connection failed: {e}")
        conn.close()
        sys.exit(1)

    cache_cursor = conn.cursor()
    dbx_cursor = databricks_conn.cursor()

    # Ensure schema exists
    dbx_cursor.execute(f"CREATE SCHEMA IF NOT EXISTS `{CATALOG}`.`{SCHEMA}`")

    # Get all base tables from Cache
    cache_cursor.execute("""
        SELECT TOP 2 TABLE_SCHEMA, TABLE_NAME
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_TYPE ='BASE TABLE'
    """)

    tables = cache_cursor.fetchall()

    print("\nWriting tables to Databricks\n")

    for source_schema, table in tables:
        try:
            # Read from Cache
            sql_table_name = f'"{source_schema}"."{table}"'
            cache_cursor.execute(f"SELECT * FROM {sql_table_name}")
            columns = cache_cursor.description

            # Destination table: devs.bronze.<schema>_<table> (lowercase)
            dest_table_name = f"{source_schema}_{table}".lower()
            full_dest = f"`{CATALOG}`.`{SCHEMA}`.`{dest_table_name}`"

            # Create table in Databricks
            create_sql = build_create_table_sql(full_dest, columns)
            dbx_cursor.execute(create_sql)

            # Insert data in chunks
            row_count = 0
            num_cols = len(columns)

            while rows := cache_cursor.fetchmany(CHUNK_SIZE):
                insert_sql = build_insert_sql(full_dest, rows)
                dbx_cursor.execute(insert_sql)
                row_count += len(rows)

            print(
                f"{sql_table_name:<10} - {row_count:>6,} rows x {num_cols} cols → {full_dest}"
            )

        except Exception as e:
            raise RuntimeError(f"{source_schema}.{table} export failed: {e}") from e

    # Clean up
    cache_cursor.close()
    conn.close()
    dbx_cursor.close()
    databricks_conn.close()

    print(f"\nAll tables written to: {CATALOG}.{SCHEMA}")


if __name__ == "__main__":
    main()
