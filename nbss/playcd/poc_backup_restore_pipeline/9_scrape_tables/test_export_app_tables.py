"""
Verifies that the tables written to Databricks by export_app_tables.py match
the base tables returned from the Cache database:
total Databricks table count equals total Cache table count
every Cache table has a corresponding Databricks table
no extra Databricks tables exist without a matching Cache table
Note: This will be called from export_app_tables.py after it finishes or can be called individually
"""

import os
import sys
import unittest
import pyodbc
from databricks import sql as databricks_sql
from databricks.sdk.core import Config
from dotenv import load_dotenv

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


def _connect_cache():
    conn = pyodbc.connect(
        f"DRIVER={{{DRIVER}}};SERVER={SERVER};PORT={PORT};"
        f"DATABASE={DATABASE};UID={UID};PWD={PWD}"
    )
    to_str = lambda v: v.decode("utf-8", errors="replace") if v is not None else None
    conn.add_output_converter(pyodbc.SQL_TYPE_DATE, to_str)
    conn.add_output_converter(pyodbc.SQL_TYPE_TIME, to_str)
    conn.add_output_converter(pyodbc.SQL_TYPE_TIMESTAMP, to_str)
    conn.add_output_converter(pyodbc.SQL_NUMERIC, to_str)
    conn.add_output_converter(pyodbc.SQL_DECIMAL, to_str)
    return conn


def _connect_databricks():
    cfg = Config(profile=DATABRICKS_PROFILE)
    return databricks_sql.connect(
        server_hostname=cfg.host.replace("https://", ""),
        http_path=DATABRICKS_HTTP_PATH,
        credentials_provider=lambda: cfg.authenticate,
    )


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


def _get_databricks_tables(dbx_conn):
    """Query Databricks to get all tables in the target schema."""
    cursor = dbx_conn.cursor()
    cursor.execute(f"SHOW TABLES IN `{CATALOG}`.`{SCHEMA}`")
    rows = cursor.fetchall()
    cursor.close()
    return {row.tableName for row in rows}


class TestExportAppTables(unittest.TestCase):

    @classmethod
    def setUpClass(cls):
        try:
            cls.cache_conn = _connect_cache()
        except pyodbc.Error as e:
            raise RuntimeError(f"Could not connect to Cache: {e}") from e

        try:
            cls.dbx_conn = _connect_databricks()
        except Exception as e:
            cls.cache_conn.close()
            raise RuntimeError(f"Could not connect to Databricks: {e}") from e

        cls.db_tables = _get_db_tables(cls.cache_conn)
        cls.dbx_tables = _get_databricks_tables(cls.dbx_conn)

        # Expected Databricks table names: <schema>_<table> in lowercase
        cls.expected_dbx_tables = {
            f"{schema}_{table}".lower() for schema, table in cls.db_tables
        }

        print(f"\nCache tables      : {len(cls.db_tables)}")
        print(f"Databricks tables : {len(cls.dbx_tables)}")

    @classmethod
    def tearDownClass(cls):
        cls.cache_conn.close()
        cls.dbx_conn.close()

    def test_databricks_count_matches_table_count(self):
        self.assertEqual(
            len(self.dbx_tables),
            len(self.expected_dbx_tables),
            f"Databricks table count ({len(self.dbx_tables)}) does not match "
            f"Cache table count ({len(self.expected_dbx_tables)})",
        )

    def test_every_table_has_a_databricks_table(self):
        missing = self.expected_dbx_tables - self.dbx_tables
        self.assertFalse(
            missing,
            f"{len(missing)} table(s) in Cache have no Databricks table:\n"
            + "\n".join(f"  {t}" for t in sorted(missing)),
        )

    def test_no_extra_databricks_tables(self):
        extra = self.dbx_tables - self.expected_dbx_tables
        self.assertFalse(
            extra,
            f"{len(extra)} Databricks table(s) have no matching Cache table:\n"
            + "\n".join(f"  {t}" for t in sorted(extra)),
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
