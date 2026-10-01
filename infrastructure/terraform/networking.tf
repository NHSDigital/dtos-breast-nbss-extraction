locals{
    hub_private_endpoint_resource_group_name = "rg-hub-${var.hub}-uks-hub-private-endpoints"
    hub_private_dns_zone_resource_group_name = "rg-hub-${var.hub}-uks-private-dns-zones"
    hub_network_resource_group_name = "rg-hub-${var.hub}-uks-hub-networking"
    hub_vnet_name = "VNET-${upper(var.hub)}-UKS-HUB"
    hub_private_endpoint_subnet_name = "SN-${upper(var.hub)}-UKS-HUB-pep"
}

data "azurerm_resource_group" "hub_private_endpoint" {
  provider = azurerm.hub
  name     = local.hub_private_endpoint_resource_group_name
}

data "azurerm_resource_group" "hub_private_dns_zones" {
  provider = azurerm.hub
  name     = local.hub_private_dns_zone_resource_group_name
}

data "azurerm_resource_group" "hub_network" {
  provider = azurerm.hub
  name     = local.hub_network_resource_group_name
}

data "azurerm_virtual_network" "hub" {
  provider            = azurerm.hub
  name                = local.hub_vnet_name
  resource_group_name = data.azurerm_resource_group.hub_network.name
}

data "azurerm_subnet" "hub_private_endpoint" {
  provider             = azurerm.hub
  name                 = local.hub_private_endpoint_subnet_name
  virtual_network_name = data.azurerm_virtual_network.hub.name
  resource_group_name  = data.azurerm_resource_group.hub_network.name
}

data "azurerm_private_dns_zone" "blob" {
  provider            = azurerm.hub
  name                = var.storage_blob_private_dns_zone_name
  resource_group_name = "rg-hub-${var.hub}-uks-private-dns-zones"
}
