# ── Workspace ────────────────────────────────────────────────────────────────

data "databricks_group" "developers" {
  display_name = "BSR-Digital-Developers"
  depends_on   = [azurerm_databricks_workspace.main]
}

resource "azurerm_databricks_workspace" "main" {
  name                        = "test-databricks-env-2"
  resource_group_name         = local.resource_group
  managed_resource_group_name = "databricks-rg-test-databricks-env-2"
  location                    = data.azurerm_resource_group.main.location
  sku                         = "premium"
}

# ── Access Connector ─────────────────────────────────────────────────────────

resource "azurerm_databricks_access_connector" "main" {
  name                = "databricks-access-connector"
  resource_group_name = local.resource_group
  location            = data.azurerm_resource_group.main.location

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "access_connector_storage" {
  scope                = azurerm_storage_account.datalake.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.main.identity[0].principal_id
}

# ── Unity Catalog ─────────────────────────────────────────────────────────────

# Storage credential — backed by the Access Connector's managed identity
resource "databricks_storage_credential" "main" {
  name  = "bsrtestdatalake_contributor"
  owner = data.azurerm_client_config.current.client_id

  azure_managed_identity {
    access_connector_id = azurerm_databricks_access_connector.main.id
  }

  depends_on = [azurerm_databricks_workspace.main]
}

# External location — points to the raw ADLS Gen2 container
resource "databricks_external_location" "raw" {
  name            = "bsrtestdatalake_raw"
  url             = "abfss://raw@${azurerm_storage_account.datalake.name}.dfs.core.windows.net/"
  credential_name = databricks_storage_credential.main.name
  owner           = data.azurerm_client_config.current.client_id
}

# Dev catalog
resource "databricks_catalog" "dev" {
  name         = "devs"
  comment      = "Development catalog for breast screening reporting"
  storage_root = "abfss://raw@${azurerm_storage_account.datalake.name}.dfs.core.windows.net/unity-catalog"
}

# Schemas
resource "databricks_schema" "bronze" {
  catalog_name = databricks_catalog.dev.name
  name         = "bronze"
}

resource "databricks_schema" "silver" {
  catalog_name = databricks_catalog.dev.name
  name         = "silver"
}

resource "databricks_schema" "gold" {
  catalog_name = databricks_catalog.dev.name
  name         = "gold"
}

# ── Grants ────────────────────────────────────────────────────────────────────

# Allow all workspace users to create their own per-dev schemas in devs
# (DABs mode: development deploys to bronze_<username>, silver_<username> etc.)
resource "databricks_grants" "dev_catalog" {
  catalog = databricks_catalog.dev.name

  grant {
    principal  = data.databricks_group.developers.display_name
    privileges = ["USE CATALOG", "CREATE SCHEMA"]
  }
}

# Allow developers to use and query the shared CI schemas
resource "databricks_grants" "bronze_schema" {
  schema = "${databricks_catalog.dev.name}.${databricks_schema.bronze.name}"

  grant {
    principal  = data.databricks_group.developers.display_name
    privileges = ["USE SCHEMA", "SELECT"]
  }
}

resource "databricks_grants" "silver_schema" {
  schema = "${databricks_catalog.dev.name}.${databricks_schema.silver.name}"

  grant {
    principal  = data.databricks_group.developers.display_name
    privileges = ["USE SCHEMA", "SELECT"]
  }
}

resource "databricks_grants" "gold_schema" {
  schema = "${databricks_catalog.dev.name}.${databricks_schema.gold.name}"

  grant {
    principal  = data.databricks_group.developers.display_name
    privileges = ["USE SCHEMA", "SELECT"]
  }
}

# Allow developers to read raw files via the external location / storage credential
# (required for DLT pipelines that use Auto Loader against ADLS)
resource "databricks_grants" "storage_credential" {
  storage_credential = databricks_storage_credential.main.id

  grant {
    principal  = data.databricks_group.developers.display_name
    privileges = ["READ FILES"]
  }
}

resource "databricks_grants" "external_location_raw" {
  external_location = databricks_external_location.raw.id

  grant {
    principal  = data.databricks_group.developers.display_name
    privileges = ["READ FILES"]
  }
}
