"""
Description:
Connects to InterSystems Cache via ODBC (DSN=NBSS_64), fetches the first 5 tables from the APP schema,
and exports each to CSV.

"""

import pyodbc
import csv
from datetime import datetime
from dotenv import load_dotenv
import os
import sys

# variables
load_dotenv()
DSN = os.getenv("DSN")
UID = os.getenv("UID")
PWD = os.getenv("PWD")
SCHEMA = "APP"  # feel free to change this to target a different schema
OUTPUT_DIR = "cache_data_export"
CHUNK_SIZE = 10000


def main():

    # connection
    try:
        conn = pyodbc.connect(f"DSN={DSN};UID={UID};PWD={PWD}")
        print("Connected!\n")
    except pyodbc.Error as e:
        print(f"Connection failed: {e.args[1]}")
        sys.exit(1)

    cursor = conn.cursor()

    # get first 5 tables from APP schema
    # feel to change query to pick up more tables or filter differently
    cursor.execute(f"""
        SELECT TOP 5 TABLE_SCHEMA, TABLE_NAME
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA = '{SCHEMA}'
        ORDER BY TABLE_SCHEMA, TABLE_NAME DESC
    """)

    tables = cursor.fetchall()

    print(f"📋 Tables found in [{SCHEMA}] schema:")
    for schema, table in tables:
        print(f"   {schema}.{table}")

    os.makedirs(OUTPUT_DIR, exist_ok=True)

    # loop through tables, fetch data, export to .csv
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

    print("\nFetching data from tables\n")

    for schema, table in tables:
        try:
            full_table_name = f"{schema}.{table}"
            SQL = f"SELECT * FROM {full_table_name}"

            cursor.execute(SQL)
            columns = [col[0] for col in cursor.description]
            filename = f"{schema}_{table}_{timestamp}.csv"
            output_path = os.path.join(OUTPUT_DIR, filename)
            total_rows = 0

            with open(output_path, "w", newline="", encoding="utf-8") as f:
                writer = csv.writer(f)
                writer.writerow(columns)
                while True:
                    rows = cursor.fetchmany(CHUNK_SIZE)
                    if not rows:
                        break
                    writer.writerows(rows)
                    total_rows += len(rows)

            print(
                f"{full_table_name:<10} - {total_rows:>6,} rows x {len(columns)} cols -> {filename}"
            )

        except Exception as e:
            print(f"{schema}.{table} failed: {e}")

    # clean up
    cursor.close()
    conn.close()

    print(f"\nAll CSVs saved to: {os.path.abspath(OUTPUT_DIR)}")


if __name__ == "__main__":
    main()
