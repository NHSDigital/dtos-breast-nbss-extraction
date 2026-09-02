# 9. Scrape the tables from Caché to Databricks

## Overview

The `export_app_tables.py` script connects to the restored CACHERESTORE instance via ODBC, fetches all base tables from all schemas, and writes each table directly to a Databricks Unity Catalog as managed Delta tables. Empty tables are also exported to preserve the schema structure.

The script:

1. **Connects** to Caché via ODBC using credentials from a `.env` file
2. **Connects** to Databricks via the SQL Connector, authenticated through the Databricks CLI
3. **Queries `INFORMATION_SCHEMA.TABLES`** to discover all base tables
4. **Creates tables** in the target schema with column types mapped from the ODBC metadata
5. **Inserts data** in chunks (10,000 rows at a time) to avoid memory issues
6. **Names tables** as `<source_schema>_<table>` in lowercase (e.g. `app_clients`, `util_users`)

## Prerequisites

- The CACHERESTORE instance must be running with the NBSS namespace available (steps 6–8 completed)
- The InterSystems ODBC driver must be installed (this is included with the Caché installation)
- The [Databricks CLI](https://docs.databricks.com/en/dev-tools/cli/install.html) must be installed and authenticated
- A running SQL warehouse in the target Databricks workspace
- Create a `.env` file in `nbss/playcd/poc_backup_restore_pipeline` with the following:

```ENVIRONMENT
DRIVER=InterSystems ODBC
SERVER=localhost
PORT=1973
DATABASE=NBSS
UID=_SYSTEM
PWD=<password for the CACHERESTORE instance>
DATABRICKS_PROFILE=dev
DATABRICKS_HTTP_PATH=/sql/1.0/warehouses/<your-warehouse-id>
CATALOG = <catalog>
SCHEMA = <schema>
```

> **Note:** The default `_SYSTEM` password for a fresh Caché install is `SYS`. If you created a custom user via `new_cache_user.ps1`, use those credentials instead.

## Scraping Tables — Option 1: Windows with Caché running natively

**Problem**: The `InterSystems ODBC` driver is registered within Windows only. The repo is set to run with Linux (due to Make), however running this script via Linux (WSL) is difficult as `InterSystems ODBC` is only accessible from Windows.

**For this reason we run the script via PowerShell using uv.**

Reference: [InterSystems ODBC](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=GEPYTHON_loadlib)

From PowerShell:

```PowerShell
cd nbss\playcd\poc_backup_restore_pipeline\9_scrape_tables
uv run export_app_tables.py
```

This will write the tables directly to the Databricks Unity Catalog.

## Scraping Tables — Option 2: Mac with Caché running in Parallels

- In Parallels, install Python 32-bit: open PowerShell and run `winget install Python.Python.3.12 --architecture x86`
- Then run `py -3.12-32 -m pip install pyodbc python-dotenv`
- Open File Explorer (in Windows) and find `dtos-breast-nbss-extraction\nbss\playcd\poc_backup_restore_pipeline\9_scrape_tables`. Most likely in 'Home on Mac (Z:/)' drive. Copy the path (for example: `Z:\dtos-breast-nbss-extraction\nbss\playcd\poc_backup_restore_pipeline\9_scrape_tables`).
- Run `cd <path from above>`
- Run `py -3.12-32 export_app_tables.py`

## Output

Tables are written to the Databricks Unity Catalog under `<catalog>.<schema>`:

```text
<catalog>.<schema>/
├── app_cdaccommodation
├── app_clients
├── app_bsodetails
├── util_users
└── ...
```

Example console output:

```output
Connected to Cache!

Connected to Databricks!

Writing tables to Databricks

"APP"."BsoDetails" -  1,234 rows x 15 cols → `<catalog>`.`<schema>`.`app_bsodetails`
"APP"."Clients"    - 56,789 rows x 42 cols → `<catalog>`.`<schema>`.`app_clients`
...

All tables written to: <catalog>.<schema>
```

## Testing

`test_export_app_tables.py` verifies that the tables written to Databricks by the export match the base tables in the restored Caché instance. It connects to both Caché and Databricks, reads the table list from each, and checks:

- The Databricks table count matches the Caché base-table count
- Every Caché table has a corresponding Databricks table (nothing missing)
- No extra Databricks tables exist without a matching Caché table

The test verifies presence and naming (`<schema>_<table>` in lowercase), not row-level data content. Run it after `export_app_tables.py` completes:

```PowerShell
# Option 1: Windows (uv)
uv run -m unittest test_export_app_tables -v

# Option 2: Mac via Parallels (32-bit Python)
py -3.12-32 -m unittest test_export_app_tables -v
```

### Comparing against the original playCD export

`test_compare_exports.py` is a deeper check that confirms the extracted Databricks tables match the **original playCD CSV export** (`nbss/playcd/data_and_code_export/cache_data_export`), not just the restored Caché instance. It reads the CSVs from disk and queries Databricks, keying both sides by the canonical `<schema>_<table>` name, and checks:

- The table count matches
- Every playCD CSV has a corresponding Databricks table (nothing missing)
- No extra Databricks tables exist without a matching CSV
- Row counts match for each table
- Column counts match for each table

Unlike `test_export_app_tables.py`, this compares **row and column counts**, so it catches lost or duplicated data. `UTIL` tables with known, expected differences (see "Note on expected row count differences" below) are allowlisted via `KNOWN_DIFF_TABLES` and reported separately rather than failing the run.

It only needs the playCD CSVs on disk and a Databricks connection (no Caché ODBC), so it can run on any machine with an authenticated Databricks CLI profile — it reads `DATABRICKS_PROFILE`, `DATABRICKS_HTTP_PATH`, `CATALOG` and `SCHEMA` from the same `.env`. Because it issues two queries per table it takes several minutes over ~670 tables.

```bash
# From nbss/ (has the databricks-sql-connector / dotenv deps)
cd nbss && uv run python playcd/poc_backup_restore_pipeline/9_scrape_tables/test_compare_exports.py
```

## Files

- `export_app_tables.py` — The main export script (connects via ODBC, writes tables to a Databricks Unity Catalog)
- `test_export_app_tables.py` — Verifies that the exported tables in Databricks match the Caché base tables (count, completeness, no extras)
- `test_compare_exports.py` — Verifies that the exported Databricks tables match the original playCD CSV export, comparing table presence, row counts and column counts
- `.env` — Connection credentials (not committed to source control; lives in `poc_backup_restore_pipeline`)

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `Access Denied (417)` | Check `UID` and `PWD` in `.env` — the default `_SYSTEM` password for a fresh install is `SYS` |
| `Driver not found` | Open 32-bit ODBC Administrator (`C:\Windows\SysWOW64\odbcad32.exe`) and check the **Drivers** tab for the exact driver name |
| `Connection failed` | Verify the CACHERESTORE instance is running and the `PORT` in `.env` matches (default: `1973`) |
| No tables exported | Check `DATABASE` in `.env` is set to `NBSS` (the namespace created during restore) |

## Note on expected row count differences

> These notes explain the differences surfaced by `test_compare_exports.py` when comparing the extracted Databricks tables against the original PlayCD export. The `UTIL` tables below are allowlisted in that test's `KNOWN_DIFF_TABLES` so they are reported but do not fail the run.

The APP-schema tables (actual NBSS patient/screening data) matched exactly. However, some `UTIL` tables showed minor row count differences. These are expected and do not indicate data loss:

### Transient/runtime data (not preserved across restore)

| Table | Explanation |
|-------|-------------|
| `UTIL.CurrentJobs` | Tracks active Caché PIDs at time of scrape. The PlayCD had processes running; the restored instance has none because no NBSS application is active. |
| `UTIL.RemoteAnalysis` | Stored in a global that maps to a system database (e.g. `CACHETEMP` or `mgr\`) which was **not** restored — only `dem_app` and `dem_dat` were. |

### Data accumulated on the PlayCD *after* the backup was taken

| Table | Explanation |
|-------|-------------|
| `UTIL.SecurityAuditTrail` | The restored data ends at the backup point. Extra entries in the original are from PlayCD usage (logins, password attempts) after the backup was taken. |
| `UTIL.SystemStatus` | Same pattern — the original has Cache startup/shutdown events from PlayCD sessions after the backup. The restored ends at the backup point, plus one new entry from the restore itself. |
| `UTIL.Routine` | Routines compiled on the PlayCD after the backup was taken. |

### Metadata generated by the restore process itself (slightly more in restored)

| Table | Explanation |
|-------|-------------|
| `UTIL.TableColumns` | Additional column definitions from objects created during restore (namespace, database configuration). |
| `UTIL.TableMethod` | Additional method definitions from the same. |
| `UTIL.TableProperties` | Additional property definitions from the same. |
