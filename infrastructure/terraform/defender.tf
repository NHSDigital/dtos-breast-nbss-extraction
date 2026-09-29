resource "azapi_resource" "defender_storage" {
  for_each = local.defender_storage_accounts

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

locals {
  defender_storage_accounts = {
    upload = azurerm_storage_account.upload.id
  }
}
