data "azurerm_client_config" "current" {}

provider "azurerm" {
  features {}
}

provider "databricks" {
  host = var.databricks_host
  # Auth auto-detected: Azure CLI locally, ARM_CLIENT_SECRET in CI
}
