"""
Verifies that the CSV files produced by export_app_tables.py match the base
tables returned from the database:
total CSV count equals total table count
every DB table has a corresponding CSV file
no extra CSV files exist without a matching DB table
Note: This will be called from export_app_tables.py after it finishes or can be called individually
"""

import os
import sys
import unittest
import pyodbc
from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))
DRIVER = os.getenv("DRIVER")
SERVER = os.getenv("SERVER")
PORT = os.getenv("PORT")
DATABASE = os.getenv("DATABASE")
UID = os.getenv("UID")
PWD = os.getenv("PWD")
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "exported_nbss_data")


def _connect():
    conn = pyodbc.connect(
        f"DRIVER={{{DRIVER}}};SERVER={SERVER};PORT={PORT};"
        f"DATABASE={DATABASE};UID={UID};PWD={PWD}"
    )
    to_str = lambda v: v.decode("utf-8") if v is not None else None
    conn.add_output_converter(pyodbc.SQL_TYPE_DATE, to_str)
    conn.add_output_converter(pyodbc.SQL_TYPE_TIME, to_str)
    conn.add_output_converter(pyodbc.SQL_TYPE_TIMESTAMP, to_str)
    return conn


def _get_db_tables(conn):
    cursor = conn.cursor()
    cursor.execute("""
        SELECT TABLE_SCHEMA, TABLE_NAME
        FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_TYPE = 'BASE TABLE'
    """)
    rows = cursor.fetchall()
    cursor.close()
    return {(schema, table) for schema, table in rows}


def _get_csv_files():
    """Walk OUTPUT_DIR and return a set of (schema, table_name) tuples."""
    found = set()
    if not os.path.isdir(OUTPUT_DIR):
        return found
    for entry in os.scandir(OUTPUT_DIR):
        if entry.is_dir():
            for f in os.scandir(entry.path):
                if f.name.endswith(".csv"):
                    found.add((entry.name, f.name[:-4]))  # strip .csv
    return found


class TestExportAppTables(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        try:
            cls.conn = _connect()
        except pyodbc.Error as e:
            raise RuntimeError(f"Could not connect to database: {e}") from e

        cls.db_tables = _get_db_tables(cls.conn)
        cls.csv_files = _get_csv_files()

        print(f"\nDB tables : {len(cls.db_tables)}")
        print(f"CSV files : {len(cls.csv_files)}")

    @classmethod
    def tearDownClass(cls):
        cls.conn.close()

    def test_csv_count_matches_table_count(self):
        self.assertEqual(
            len(self.csv_files),
            len(self.db_tables),
            f"CSV file count ({len(self.csv_files)}) does not match "
            f"DB table count ({len(self.db_tables)})",
        )

    def test_every_table_has_a_csv(self):
        missing = self.db_tables - self.csv_files
        self.assertFalse(
            missing,
            f"{len(missing)} table(s) in the DB have no CSV:\n"
            + "\n".join(f"  {s}.{t}" for s, t in sorted(missing)),
        )

    def test_no_extra_csvs(self):
        extra = self.csv_files - self.db_tables
        self.assertFalse(
            extra,
            f"{len(extra)} CSV file(s) have no matching DB table:\n"
            + "\n".join(f"  {s}.{t}" for s, t in sorted(extra)),
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
