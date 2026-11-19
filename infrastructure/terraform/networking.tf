locals {
  hub_private_dns_zone_resource_group_name = "rg-hub-${var.hub}-uks-private-dns-zones"
  hub_network_resource_group_name          = "rg-hub-${var.hub}-uks-hub-networking"
  hub_vnet_name                            = "VNET-${upper(var.hub)}-UKS-HUB"
}

data "azurerm_virtual_network" "hub" {
  provider = azurerm.hub

  name                = local.hub_vnet_name
  resource_group_name = local.hub_network_resource_group_name
}

data "azurerm_private_dns_resolver" "hub" {
  provider = azurerm.hub

  name                = "${var.hub}-uks-hub-private-dns-zone-resolver"
  resource_group_name = local.hub_private_dns_zone_resource_group_name
}

data "azurerm_private_dns_resolver_inbound_endpoint" "hub" {
  provider = azurerm.hub

  name                    = "private-dns-resolver-inbound-endpoint"
  private_dns_resolver_id = data.azurerm_private_dns_resolver.hub.id
}

data "azurerm_private_dns_zone" "blob" {
  provider            = azurerm.hub
  name                = var.storage_blob_private_dns_zone_name
  resource_group_name = local.hub_private_dns_zone_resource_group_name
}

module "nbss_log_analytics_workspace" {
  source = "../modules/dtos-devops-templates/infrastructure/modules/log-analytics-workspace"

  name                = module.shared_config.names["log-analytics-workspace"]
  resource_group_name = azurerm_resource_group.deploy_resource_group.name
  location            = local.region
  law_sku             = "PerGB2018"
  retention_days      = var.log_analytics_retention_days

  monitor_diagnostic_setting_log_analytics_workspace_enabled_logs = ["Audit"]
  monitor_diagnostic_setting_log_analytics_workspace_metrics      = ["AllMetrics"]
}

module "nbss_vnet" {
  source = "../modules/dtos-devops-templates/infrastructure/modules/vnet"

  name                = module.shared_config.names["virtual-network"]
  resource_group_name = azurerm_resource_group.deploy_resource_group.name
  location            = local.region
  vnet_address_space  = var.nbss_vnet_address
  dns_servers         = [data.azurerm_private_dns_resolver_inbound_endpoint.hub.ip_configurations[0].private_ip_address]

  log_analytics_workspace_id                   = module.nbss_log_analytics_workspace.id
  monitor_diagnostic_setting_vnet_enabled_logs = []
  monitor_diagnostic_setting_vnet_metrics      = ["AllMetrics"]
}

module "peering_spoke_hub" {
  source = "../modules/dtos-devops-templates/infrastructure/modules/vnet-peering"

  name                = "${module.nbss_vnet.name}-to-hub-peering"
  resource_group_name = azurerm_resource_group.deploy_resource_group.name
  vnet_name           = module.nbss_vnet.name
  remote_vnet_id      = data.azurerm_virtual_network.hub.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

module "peering_hub_spoke" {
  source = "../modules/dtos-devops-templates/infrastructure/modules/vnet-peering"

  providers = {
    azurerm = azurerm.hub
  }

  name                = "hub-to-${module.nbss_vnet.name}-peering"
  resource_group_name = local.hub_network_resource_group_name
  vnet_name           = data.azurerm_virtual_network.hub.name
  remote_vnet_id      = module.nbss_vnet.vnet.id

  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

module "nbss_private_endpoint_subnet" {
  source = "../modules/dtos-devops-templates/infrastructure/modules/subnet"

  name                = "${module.shared_config.names["subnet"]}-pep"
  resource_group_name = azurerm_resource_group.deploy_resource_group.name
  location            = local.region
  vnet_name           = module.nbss_vnet.name
  address_prefixes    = var.pep_subnet_address

  create_nsg                                                     = false
  network_security_group_name                                    = module.shared_config.names["network-security-group"]
  log_analytics_workspace_id                                     = module.nbss_log_analytics_workspace.id
  monitor_diagnostic_setting_network_security_group_enabled_logs = []
}
