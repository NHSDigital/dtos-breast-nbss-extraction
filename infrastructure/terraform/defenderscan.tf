locals {
  defender_scan_function_app_name     = "func-${var.app_short_name}-${var.env_config}-defender-scan"
  defender_scan_service_plan_name     = "asp-${var.app_short_name}-${var.env_config}-defender-scan"
  defender_scan_function_storage_name = substr(replace("sa${var.app_short_name}${var.environment}fnscan", "/[^0-9a-z]/", ""), 0, 24)
  defender_scan_results_queue_name    = "defender-scan-results"
}

resource "azurerm_service_plan" "defender_scan" {
  name                = local.defender_scan_service_plan_name
  resource_group_name = azurerm_resource_group.deploy_resource_group.name
  location            = azurerm_resource_group.deploy_resource_group.location

  os_type  = "Linux"
  sku_name = var.defender_scan_service_plan_sku
}

# Runtime storage for the Function App and Event Grid queue delivery.
# Kept network-reachable to Azure services so the host and Event Grid can use
# queues without spoke VNet integration. The Function App itself is private.
resource "azurerm_storage_account" "defender_scan_function" {
  name                = local.defender_scan_function_storage_name
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

  public_network_access_enabled = true
  shared_access_key_enabled     = true

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }
}

resource "azurerm_storage_queue" "defender_scan_results" {
  name               = local.defender_scan_results_queue_name
  storage_account_id = azurerm_storage_account.defender_scan_function.id
}

resource "azurerm_linux_function_app" "defender_scan" {
  name                = local.defender_scan_function_app_name
  resource_group_name = azurerm_resource_group.deploy_resource_group.name
  location            = azurerm_resource_group.deploy_resource_group.location
  service_plan_id     = azurerm_service_plan.defender_scan.id

  storage_account_name       = azurerm_storage_account.defender_scan_function.name
  storage_account_access_key = azurerm_storage_account.defender_scan_function.primary_access_key

  https_only                    = true
  public_network_access_enabled = false
  builtin_logging_enabled       = false
  virtual_network_subnet_id     = azurerm_subnet.defender_scan_vnet_integration.id

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME      = "python"
    AzureWebJobsFeatureFlags      = "EnableWorkerIndexing"
    DEFENDER_STORAGE_ACCOUNT_NAME = azurerm_storage_account.defender_storage_account.name
    CLEAN_CONTAINER_NAME          = "clean-scans"
    QUARANTINE_CONTAINER_NAME     = "quarantine-scans"
    DEFENDER_SCAN_RESULTS_QUEUE   = azurerm_storage_queue.defender_scan_results.name
  }

  site_config {
    always_on                         = true
    ftps_state                        = "Disabled"
    minimum_tls_version               = "1.2"
    http2_enabled                     = true
    scm_minimum_tls_version           = "1.2"
    vnet_route_all_enabled            = true
    ip_restriction_default_action     = "Deny"
    scm_ip_restriction_default_action = "Deny"

    application_stack {
      python_version = var.defender_scan_python_version
    }
  }
}

resource "azurerm_private_endpoint" "defender_scan_function_app" {
  provider            = azurerm.hub
  name                = "${local.defender_scan_function_app_name}-pep"
  location            = data.azurerm_resource_group.hub_private_endpoint.location
  resource_group_name = data.azurerm_resource_group.hub_private_endpoint.name
  subnet_id           = data.azurerm_subnet.hub_private_endpoint.id

  private_service_connection {
    name                           = "${local.defender_scan_function_app_name}-sites"
    private_connection_resource_id = azurerm_linux_function_app.defender_scan.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "${local.defender_scan_function_app_name}-sites-dns"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.azurewebsites.id]
  }
}

resource "azurerm_role_assignment" "defender_scan_upload_blob_contributor" {
  for_each = local.upload_accounts_map

  scope                = azurerm_storage_account.upload_accounts[each.key].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_function_app.defender_scan.identity[0].principal_id
}

resource "azurerm_role_assignment" "defender_scan_defender_blob_contributor" {
  scope                = azurerm_storage_account.defender_storage_account.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_function_app.defender_scan.identity[0].principal_id
}

resource "azurerm_role_assignment" "defender_scan_function_storage_blob_contributor" {
  scope                = azurerm_storage_account.defender_scan_function.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_function_app.defender_scan.identity[0].principal_id
}
