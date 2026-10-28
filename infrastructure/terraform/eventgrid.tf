locals {
  defender_scan_event_grid_topic_name   = "evgt-${var.app_short_name}-${var.env_config}-defender-scan"
  defender_scan_event_subscription_name = "evgs-${var.app_short_name}-${var.env_config}-defender-scan"
  eventgrid_dead_letter_container_name  = "eventgrid-deadletter"
}

# Defender for Storage requires a custom Event Grid topic with public network access
# enabled so scan-result events can be published. Private-endpoint-only topics are not
# supported for this notification path.
resource "azurerm_eventgrid_topic" "defender_scan" {
  name                = local.defender_scan_event_grid_topic_name
  resource_group_name = azurerm_resource_group.deploy_resource_group.name
  location            = azurerm_resource_group.deploy_resource_group.location

  input_schema                  = "EventGridSchema"
  public_network_access_enabled = true
  local_auth_enabled            = true

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_storage_container" "eventgrid_dead_letter" {
  name                  = local.eventgrid_dead_letter_container_name
  storage_account_id    = azurerm_storage_account.defender_scan_function.id
  container_access_type = "private"
}

data "azurerm_storage_account" "upload_accounts_identity" {
  for_each = local.upload_accounts_map

  name                = each.value.account_name
  resource_group_name = azurerm_resource_group.deploy_resource_group.name

  depends_on = [azurerm_storage_account.upload_accounts]
}

# Allow each upload storage account to publish malware scan results to the topic.
resource "azurerm_role_assignment" "upload_eventgrid_data_sender" {
  for_each = local.upload_accounts_map

  scope                = azurerm_eventgrid_topic.defender_scan.id
  role_definition_name = "EventGrid Data Sender"
  principal_id         = data.azurerm_storage_account.upload_accounts_identity[each.key].identity[0].principal_id
}

# Deliver scan results to a storage queue so the Function App can remain private
# (no public inbound). The Python function consumes the queue.
resource "azurerm_eventgrid_event_subscription" "defender_scan" {
  name  = local.defender_scan_event_subscription_name
  scope = azurerm_eventgrid_topic.defender_scan.id

  included_event_types = [
    "Microsoft.Security.MalwareScanningResult",
  ]

  storage_queue_endpoint {
    storage_account_id = azurerm_storage_account.defender_scan_function.id
    queue_name         = azurerm_storage_queue.defender_scan_results.name
  }

  storage_blob_dead_letter_destination {
    storage_account_id          = azurerm_storage_account.defender_scan_function.id
    storage_blob_container_name = azurerm_storage_container.eventgrid_dead_letter.name
  }

  retry_policy {
    max_delivery_attempts = 10
    event_time_to_live    = 1440
  }

  depends_on = [
    azurerm_role_assignment.upload_eventgrid_data_sender,
  ]
}
