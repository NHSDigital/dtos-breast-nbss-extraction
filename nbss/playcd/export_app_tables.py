"""
Description:
Connects to InterSystems Cache via ODBC (DSN=NBSS_64), fetches the first 5 tables from the APP schema,
loads each into a pandas DataFrame and exports to CSV.
Note: retireved empty tables, in additon to the tables with data to the structure
"""
import pyodbc
import pandas as pd
from datetime import datetime
from dotenv import load_dotenv
import os
import sys

# variables
load_dotenv()
DSN = os.getenv("DSN")
UID = os.getenv("UID")
PWD = os.getenv("PWD")
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

            chunks = []
            while rows := cursor.fetchmany(CHUNK_SIZE):
                chunks.append(pd.DataFrame.from_records(rows, columns=columns))

            df = pd.concat(chunks, ignore_index=True) if chunks else pd.DataFrame(columns=columns)

            # save files
            filename    = f"{table}.csv"
            schema_dir  = f"{OUTPUT_DIR}/{schema}"
            os.makedirs(schema_dir, exist_ok=True)
            output_path = os.path.join(schema_dir, f"{table}.csv")
            df.to_csv(output_path, index=False)

            print(f"{full_table_name:<10} - {df.shape[0]:>6,} rows x {df.shape[1]} cols → {table}.csv")

        except Exception as e:
            print(f"{schema}.{table} failed: {e}")

    # clean up
    cursor.close()
    conn.close()

    print(f"\nAll CSVs saved to: {os.path.abspath(OUTPUT_DIR)}")

if __name__ == "__main__":
    main()