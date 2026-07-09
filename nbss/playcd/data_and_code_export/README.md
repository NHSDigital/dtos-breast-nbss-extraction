# NBSS Caché Export

## 1. Exporting code from Caché

In the Caché terminal, switch to the NBSS_DEM namespace:

```ObjectScript
ZN "NBSS_DEM"
```

Then export all classes, routines, and includes:

```ObjectScript
Set localFolder = "<INSERT LOCAL FOLDER>"
Do ##class(%SYSTEM.OBJ).Export("*.cls,*.mac,*.inc,",localFolder_"/all_files_export.xml")
```

NB: use '/' not '\' in filepaths.

### Unpacking

1. Move the exported XML file to `cache_scripts_export`
2. Run `uv run unpack_scripts.py`

This splits the large export into individual XML files organised by type (`cls/`, `mac/`, `inc/`).

## 2. Exporting data from Caché

Connects to NBSS_DEM via ODBC, fetches all tables and exports to CSV.

### Prerequisites

- Create a `.env` file in `nbss/playcd/data_and_code_export` and add the following:

```ENVIRONMENT
DRIVER=InterSystems ODBC
SERVER=127.0.0.1
PORT=1972
DATABASE=NBSS_DEM
UID=<username for NBSS_DEM data source>
PWD=<password for NBSS_DEM data source>
```

- (Optional) Within the local environment where Caché runs, set up the NBSS_DEM ODBC Data Source (Set up Part B - [ODBC Connector](https://nhsd-confluence.digital.nhs.uk/spaces/DTS/pages/1373789640/DSTA-554+Access+data+stored+in+Cache))

### Scraping Tables - Option 1: Windows with Caché running natively

**Problem**: Exporting the data is bit more complex as Caché installed `InterSystems ODBC` within `windows`. The repo is set to run with Linux (due to Make), however running this script via Linux (WSL) is difficult due to `InterSystems ODBC` only accessible via windows.

**_For meantime we will run this script via Powershell_**

Reference [InterSystem ODBC](https://docs.intersystems.com/irislatest/csp/docbook/DocBook.UI.Page.cls?KEY=GEPYTHON_loadlib)

- Run (via powershell due to ODBC connectors installed via Caché):

```PowerShell
cd nbss
Remove-Item -Recurse -Force .venv # if there is already .venv created
cd playcd/data_and_code_export
uv run export_app_tables.py
````

This will save the tables as .csv into the folder `\cache_data_export`

### Scraping Tables - Option 2: Mac with Caché running in Parallels

- In Parallels, install Python 32-bit: open powershell and run `winget install Python.Python.3.12 --architecture x86`
- Then run `py -3.12-32 -m pip install pyodbc python-dotenv`
- Open file explorer (in Windows) and find `dtos-breast-nbss-extraction\nbss\playcd\data_and_code_export`. Most likely in 'Home on Mac (Z:/)' drive. Copy the path (for example: `Z:\dtos-breast-nbss-extraction\nbss\playcd\data_and_code_export`).
- run `cd <path from above>`
- run `py -3.12-32 export_app_tables.py`
