resource "azapi_resource_action" "defender_storage" {
  for_each = local.defender_storage_accounts

  type      = "Microsoft.Security/defenderForStorageSettings@2026-01-01-preview"
  method = "PUT"
  resource_id = "${each.value}/providers/Microsoft.Security/defenderForStorageSettings/current"

  body = {
    properties = {
      isEnabled = true

      # only provide if the storage accounts absolutely must have their own settings
      overrideSubscriptionLevelSettings = true

      malwareScanning = {
          blobScanResultsOptions = "BlobIndexTags"
          onUpload = {
            isEnabled     = true
            capGBPerMonth = 5000
          }
        }

      sensitiveDataDiscovery = {
        isEnabled = true
      }
    }
  }
}

locals {
  defender_storage_accounts = {
    upload = azurerm_storage_account.upload.id
  }
}
