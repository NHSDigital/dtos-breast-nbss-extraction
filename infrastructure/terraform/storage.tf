locals {
  base_storage_account_name = substr(replace("sa${var.app_short_name}${var.environment}", "/[^0-9a-z]/", ""), 0, 24)

  shared_upload_accounts = [
    {
      account_name = "${local.base_storage_account_name}uploads"
      containers = [
        {
          container_name      = "user-uploads"
          security_group_name = "screening_nbsse_dev"
        }
      ]
    }
  ]

  # If using per-trust upload accounts, follow this structure. Also please ensure
  # that the shared_upload_accounts structure is the same as this one if you ever
  # need to modify either structure.
  per_trust_upload_accounts = [

    # {
    #   account_name        = "${local.base_storage_account_name}XXXX"
    #   container           = "user-data"
    #   security_group_name = "screening_nbsse_dev"
    #   containers          = null
    # },
  ]

  temp_upload_accounts = var.storage_layout == "shared" ? local.shared_upload_accounts : local.per_trust_upload_accounts

  # Extract all accounts into a single structure
  # account_name + containers[]
  #where each container has container_name + security_group_name.
  upload_accounts = [
    for account in local.temp_upload_accounts : {
      account_name = account.account_name
      containers = can(account.containers) ? account.containers : [
        {
          container_name      = try(account.container, "user-data")
          security_group_name = try(account.security_group_name, "screening_nbsse_dev")
        }
      ]
    }
  ]

  upload_accounts_map = {
    for account in local.upload_accounts :
    account.account_name => account
  }

  upload_containers = {
    for item in flatten([
      for account in local.upload_accounts : [
        for container in account.containers : {
          key = "${account.account_name}-${try(container.container_name, "user-data")}"
          value = {
            account_name        = account.account_name
            container_name      = try(container.container_name, "user-data")
            security_group_name = try(container.security_group_name, "screening_nbsse_dev")
          }
        }
      ]
    ]) :
    item.key => item.value
  }
}

resource "azurerm_storage_account" "upload_accounts" {
  for_each                 = local.upload_accounts_map
  name                     = each.value.account_name
  resource_group_name      = azurerm_resource_group.deploy_resource_group.name
  location                 = azurerm_resource_group.deploy_resource_group.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"

  allow_nested_items_to_be_public   = false
  cross_tenant_replication_enabled  = false
  default_to_oauth_authentication   = true
  https_traffic_only_enabled        = true
  infrastructure_encryption_enabled = true
  min_tls_version                   = "TLS1_2"

  # The endpoint is intentionally internet-routable; data access still requires authentication.
  # Please note, using public network access requires CCOE exemption setup at the subscription level
  # and approved by security team. Without this exemption in place, deployment of the storage
  # account will fail with a policy violation. For additional details, please see Risk ID 1386.
  public_network_access_enabled = true

  # The intention for the storage account is to provide Shared Key access and also Entra ID authentication.
  shared_access_key_enabled = true
}

resource "azurerm_storage_container" "upload_containers" {
  for_each              = local.upload_containers
  name                  = each.value.container_name
  storage_account_id    = azurerm_storage_account.upload_accounts[each.value.account_name].id
  container_access_type = "private"
}
