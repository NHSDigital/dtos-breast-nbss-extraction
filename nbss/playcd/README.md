# NBSS Cache Export

## Exporting from Cache

In the Cache terminal, switch to the NBSS_DEM namespace:

```ObjectScript
ZN "NBSS_DEM"
```

Then export all classes, routines, and includes:

```ObjectScript
Set localFolder = "<INSERT LOCAL FOLDER>"
Do ##class(%SYSTEM.OBJ).Export("*.cls,*.mac,*.inc,",localFolder_"/all_files_export.xml")
```

NB: use '/' not '\' in filepaths.

## Unpacking

1. Move the exported XML file to `cache_export`
2. Run `python unpack.py`

This splits the large export into individual XML files organised by type (`cls/`, `mac/`, `inc/`).

# NBSS Scrape

Connects to InterSystems Cache via ODBC (DSN=NBSS_64), fetches the first 5 tables from the APP schema, loads each into a pandas DataFrame and exports to CSV.

## Prerequisite 

- Within the local environment you are running ensure you have set up the ODBC Data Sources (Set up Part B - [ODBC Connector](https://nhsd-confluence.digital.nhs.uk/spaces/DTS/pages/1373789640/DSTA-554+Access+data+stored+in+Cache) )

- `.env` for the variables for DSN (ODBC)
 
## Scraping Tables

1. Run `python export_app_tables.py`

This will save the tables as .csv into the folder `\extracts`
