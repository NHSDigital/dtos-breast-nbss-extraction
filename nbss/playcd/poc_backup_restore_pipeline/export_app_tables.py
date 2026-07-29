"""
Description:
Connects to InterSystems Cache via ODBC, fetches all base tables,
loads each into a CSV export.
Note: retrieved empty tables, in addition to the tables with data to preserve the structure
"""

import csv
import pyodbc
from dotenv import load_dotenv
import os
import sys

# variables
load_dotenv()
DRIVER = os.getenv("DRIVER")
SERVER = os.getenv("SERVER")
PORT = os.getenv("PORT")
DATABASE = os.getenv("DATABASE")
UID = os.getenv("UID")
PWD = os.getenv("PWD")

OUTPUT_DIR = "cache_data_export"
CHUNK_SIZE = 10000


def main():

    # connection
    try:
        conn = pyodbc.connect(
            f"DRIVER={{{DRIVER}}};SERVER={SERVER};PORT={PORT};DATABASE={DATABASE};UID={UID};PWD={PWD}"
        )
        # out-of-range cannot parse.
        to_str = lambda v: v.decode("utf-8") if v is not None else None
        conn.add_output_converter(pyodbc.SQL_TYPE_DATE, to_str)
        conn.add_output_converter(pyodbc.SQL_TYPE_TIME, to_str)
        conn.add_output_converter(pyodbc.SQL_TYPE_TIMESTAMP, to_str)
        print("Connected!\n")
    except pyodbc.Error as e:
        print(f"Connection failed: {e.args[1]}")
        sys.exit(1)

    cursor = conn.cursor()

    # get all base tables
    cursor.execute("""
        SELECT TABLE_SCHEMA, TABLE_NAME
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_TYPE ='BASE TABLE'
    """)

    tables = cursor.fetchall()
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    print("\nFetching data from tables\n")

    for schema, table in tables:
        try:
            full_table_name = f"{schema}.{table}"
            cursor.execute(f"SELECT * FROM {full_table_name}")
            columns = [col[0] for col in cursor.description]

            schema_dir = f"{OUTPUT_DIR}/{schema}"
            os.makedirs(schema_dir, exist_ok=True)
            output_path = os.path.join(schema_dir, f"{table}.csv")

            row_count = 0
            with open(output_path, "w", newline="", encoding="utf-8") as f:
                writer = csv.writer(f)
                writer.writerow(columns)
                while rows := cursor.fetchmany(CHUNK_SIZE):
                    writer.writerows(rows)
                    row_count += len(rows)

            print(
                f"{full_table_name:<10} - {row_count:>6,} rows x {len(columns)} cols → {table}.csv"
            )

        except Exception as e:
            print(f"{schema}.{table} failed: {e}")

    # clean up
    cursor.close()
    conn.close()

    print(f"\nAll CSVs saved to: {os.path.abspath(OUTPUT_DIR)}")


if __name__ == "__main__":
    main()
