locals {
  defender_upload_storage_account_name =substr(replace("sa${var.app_short_name}${var.environment}upload", "/[^0-9a-z]/", ""), 0, 24)
  defender_containers = [
    "clean_scans",
    "quarantine_scans"
  ]

  defender_target_storage_accounts = {
    for storage_account_id in toset([
      for container in values(local.upload_container_urls) : container.storage_account_id
    ]) :
    storage_account_id => storage_account_id
  }
}

# Turn on Defender for all trust upload storage accounts
resource "azapi_resource" "defender_storage" {
  for_each  = local.defender_target_storage_accounts

  type      = "Microsoft.Security/defenderForStorageSettings@2026-01-01-preview"
  name      = "current"
  parent_id = each.value

  body = {
    properties = {
      isEnabled = var.scan_is_enabled

      # only provide if the storage accounts absolutely must have their own settings
      overrideSubscriptionLevelSettings = var.override_subscription_settings_enabled

      malwareScanning = {
          blobScanResultsOptions = "BlobIndexTags"
          onUpload = {
            isEnabled     = var.malware_scanning_on_upload_enabled && var.scan_is_enabled
            capGBPerMonth = var.malware_scanning_on_upload_cap_gb_per_month
          }
        }

      sensitiveDataDiscovery = {
        isEnabled = var.sensitive_data_discovery_enabled && var.scan_is_enabled
      }
    }
  }
}

# for the incoming function that triggers a move from the upload container to the defender storage account containers
# we need to ensure that the defender storage accounts are properly configured and accessible
# Since Defender storage accounts are not publicly accessible, we don't need to worry about write-only
# permissions as we do with the client landing containers

resource "azurerm_storage_account" "defender_scanned_uploads" {
  name                = local.defender_upload_storage_account_name
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

  public_network_access_enabled = false

  # The intention for the storage account is to provide Shared Key access and also Entra ID authentication.
  shared_access_key_enabled     = true
}

resource "azurerm_storage_container" "scanned_uploads" {
  for_each              = toset(local.defender_containers)
  name                  = each.key
  storage_account_id    = azurerm_storage_account.defender_scanned_uploads.id
  container_access_type = "private"
}
