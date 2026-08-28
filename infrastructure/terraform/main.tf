resource "azurerm_resource_group" "deploy_resource_group" {
  provider = azurerm
  name     = local.resource_group_name
  location = local.region
}

module "shared_config" {
  source = "../modules/dtos-devops-templates/infrastructure/modules/shared-config"

  env         = var.env_config
  location    = local.region
  application = var.app_short_name
}

locals{
    resource_group_name = "rg-${var.app_short_name}-${var.env_config}-uks"
    region              = "uksouth"
}
