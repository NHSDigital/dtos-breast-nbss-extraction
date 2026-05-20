
import pyodbc
import pandas as pd
from datetime import datetime
import os
import sys
 
# variables
DSN        = "NBSS_64"
UID        = "_SYSTEM"
PWD        = "SYS"
SQL        = "SELECT AccommodationCode, EnabledDisabled, AccomodationDescription FROM APP.CDAccommodation"
OUTPUT_DIR = "extracts"
CHUNK_SIZE = 10000
 
 
def main():
 
    # Connect
    try:
        conn = pyodbc.connect(f"DSN={DSN};UID={UID};PWD={PWD}")
        print(f"Connected to DSN={DSN} - ODBC")
    except pyodbc.Error as e:
        print(f"Connection failed: {e.args[1]}")
        sys.exit(1)
 
    # Query
    cursor = conn.cursor()
    cursor.execute(SQL)
    columns = [col[0] for col in cursor.description]
 
    # break it down to get data
    chunks     = []
    total_rows = 0
 
    print("Get data from NBSS_DEM")
 
    while True:
        rows = cursor.fetchmany(CHUNK_SIZE)
        if not rows:
            break
        chunks.append(pd.DataFrame.from_records(rows, columns=columns))
        total_rows += len(rows)
        print(f"   Fetched {total_rows:,} rows so far...")
 
    # DF
    df = pd.concat(chunks, ignore_index=True) if chunks else pd.DataFrame(columns=columns)
    print(f"\nLoaded {df.shape[0]:,} rows x {df.shape[1]} columns")
 
    # export to .csv
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    timestamp   = datetime.now().strftime("%Y%m%d_%H%M%S")
    output_path = os.path.join(OUTPUT_DIR, f"CDAccommodation_{timestamp}.csv")
 
    df.to_csv(output_path, index=False)
    print(f"Saved to: {output_path}")
 
    # clean up
    cursor.close()
    conn.close()
    print("\nCompleted! - Now another 100+ tables :)")
 
 
if __name__ == "__main__":
    main()
 

