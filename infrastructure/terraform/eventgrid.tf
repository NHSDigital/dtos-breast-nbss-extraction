locals {
  defender_scan_event_grid_topic_name   = "evgt-${var.app_short_name}-${var.env_config}-defender-scan"
  defender_scan_event_subscription_name = "evgs-${var.app_short_name}-${var.env_config}-defender-scan"
  eventgrid_dead_letter_container_name  = "eventgrid-deadletter"
}

# The private endpoint is created separately below because it must live in the hub
# subscription, which the event-grid-topic module cannot target.
module "defender_scan_event_grid_topic" {
  source = "../modules/dtos-devops-templates/infrastructure/modules/event-grid-topic"

  topic_name                    = local.defender_scan_event_grid_topic_name
  resource_group_name           = azurerm_resource_group.deploy_resource_group.name
  location                      = azurerm_resource_group.deploy_resource_group.location
  identity_type                 = "SystemAssigned"
  public_network_access_enabled = false
  private_endpoint_properties   = null
}

moved {
  from = azurerm_eventgrid_topic.defender_scan
  to   = module.defender_scan_event_grid_topic.azurerm_eventgrid_topic.azurerm_eventgrid
}

# The module does not output the topic's system-assigned identity, so look up its service principal.
data "azuread_service_principal" "defender_scan_event_grid_topic" {
  display_name = local.defender_scan_event_grid_topic_name

  depends_on = [module.defender_scan_event_grid_topic]
}

module "defender_scan_event_grid_topic_private_endpoint" {
  source = "../modules/dtos-devops-templates/infrastructure/modules/private-endpoint"

  providers = {
    azurerm = azurerm.hub
  }

  name                = "${local.defender_scan_event_grid_topic_name}-azure-eventgrid-pep"
  resource_group_name = data.azurerm_resource_group.hub_private_endpoint.name
  location            = data.azurerm_resource_group.hub_private_endpoint.location
  subnet_id           = data.azurerm_subnet.hub_private_endpoint.id

  private_dns_zone_group = {
    name                 = "${local.defender_scan_event_grid_topic_name}-pep-zone-group"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.event_grid.id]
  }

  private_service_connection = {
    name                           = "${local.defender_scan_event_grid_topic_name}-pep-connection"
    private_connection_resource_id = module.defender_scan_event_grid_topic.id
    subresource_names              = ["topic"]
    is_manual_connection           = false
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

  scope                = module.defender_scan_event_grid_topic.id
  role_definition_name = "EventGrid Data Sender"
  principal_id         = data.azurerm_storage_account.upload_accounts_identity[each.key].identity[0].principal_id
}

# Deliver scan results to a storage queue so the Function App can remain private
# (no public inbound). The Python function consumes the queue.
resource "azurerm_eventgrid_event_subscription" "defender_scan" {
  name  = local.defender_scan_event_subscription_name
  scope = module.defender_scan_event_grid_topic.id

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

  delivery_identity {
    type = "SystemAssigned"
  }

  dead_letter_identity {
    type = "SystemAssigned"
  }

  retry_policy {
    max_delivery_attempts = 10
    event_time_to_live    = 1440
  }

  depends_on = [
    azurerm_role_assignment.upload_eventgrid_data_sender,
    azurerm_role_assignment.eventgrid_queue_sender,
    azurerm_role_assignment.eventgrid_deadletter_blob_contributor,
  ]
}

resource "azurerm_role_assignment" "eventgrid_queue_sender" {
  scope                = azurerm_storage_account.defender_scan_function.id
  role_definition_name = "Storage Queue Data Message Sender"
  principal_id         = data.azuread_service_principal.defender_scan_event_grid_topic.object_id
}

resource "azurerm_role_assignment" "eventgrid_deadletter_blob_contributor" {
  scope                = azurerm_storage_account.defender_scan_function.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azuread_service_principal.defender_scan_event_grid_topic.object_id
}
