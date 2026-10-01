locals {
  defender_upload_storage_account_name =substr(replace("sa${var.app_short_name}${var.environment}defender", "/[^0-9a-z]/", ""), 0, 24)

  defender_containers = [
    "clean-scans",
    "quarantine-scans"
  ]

  defender_target_storage_accounts = {
    for container_key, container in local.upload_container_urls :
    container_key => container.storage_account_id
  }
}

# Configure Defender for all trust upload storage accounts
# Use "update" to modify existing Defender for Storage settings rather than creating new ones
resource "azapi_update_resource" "defender_settings" {
  for_each  = local.defender_target_storage_accounts

  type      = "Microsoft.Security/defenderForStorageSettings@2026-01-01-preview"
  resource_id = "${each.value}/providers/Microsoft.Security/defenderForStorageSettings/current"

  body = {
    properties = {
        isEnabled = var.scan_is_enabled

        # only provide if the storage accounts absolutely must have their own settings
        overrideSubscriptionLevelSettings = var.override_subscription_settings_enabled

        sensitiveDataDiscovery = {
          isEnabled = var.sensitive_data_discovery_enabled && var.scan_is_enabled
        }

        malwareScanning = {
          blobScanResultsOptions = "BlobIndexTags"
          onUpload = {
            isEnabled     = var.malware_scanning_on_upload_enabled && var.scan_is_enabled
            capGBPerMonth = var.malware_scanning_on_upload_cap_gb_per_month
          }
        }
    }
  }
}

# for the incoming function that triggers a move from the upload container to the defender storage account containers
# we need to ensure that the defender storage accounts are properly configured and accessible
# Since Defender storage accounts are not publicly accessible, we don't need to worry about write-only
# permissions as we do with the client landing containers

resource "azurerm_storage_account" "defender_storage_account" {
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

resource "azurerm_storage_container" "defender_containers" {
  for_each              = toset(local.defender_containers)
  name                  = each.key
  storage_account_id    = azurerm_storage_account.defender_storage_account.id
  container_access_type = "private"
}

resource "azurerm_private_endpoint" "defender_storage_blob" {
  provider            = azurerm.hub
  name                = "${local.defender_upload_storage_account_name}-pep"
  location            = data.azurerm_resource_group.hub_private_endpoint.location
  resource_group_name = data.azurerm_resource_group.hub_private_endpoint.name
  subnet_id           = data.azurerm_subnet.hub_private_endpoint.id

  private_service_connection {
    name                           = "${local.defender_upload_storage_account_name}-blob"
    private_connection_resource_id = azurerm_storage_account.defender_storage_account.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "${local.defender_upload_storage_account_name}-blob-dns"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.blob.id]
  }
}
