locals {
  upload_storage_account_name = substr(replace("sa${var.app_short_name}${var.environment}upload", "/[^0-9a-z]/", ""), 0, 24)
}

resource "azurerm_storage_account" "upload" {
  name                = local.upload_storage_account_name
  resource_group_name = azurerm_resource_group.deploy_resource_group.name
  location            = azurerm_resource_group.deploy_resource_group.location

  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  allow_nested_items_to_be_public   = false
  cross_tenant_replication_enabled  = false
  default_to_oauth_authentication   = true
  https_traffic_only_enabled        = true
  infrastructure_encryption_enabled = true
  min_tls_version                   = "TLS1_2"

  # The endpoint is intentionally internet-routable; data access still requires authentication.
  # Please note, using public network access requires CCOE exemption setup at the subscription level
  # and approved by security team. Without this exemption in place, deployment of the storage
  # account will fail with a policy violation. For additional details, please see Risk ID 1386.
  public_network_access_enabled = true

  # The intention for the storage account is to provide Shared Key access and also Entra ID authentication.
  shared_access_key_enabled     = true
}

resource "azurerm_storage_container" "upload" {
  name                  = "uploads"
  storage_account_id    = azurerm_storage_account.upload.id
  container_access_type = "private"
}
