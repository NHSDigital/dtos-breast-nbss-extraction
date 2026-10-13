locals {
  # we dont want accounts to start with numbers
  base_storage_account_name = replace("sa${var.app_short_name}${var.environment}", "/[^0-9a-z]/", "")

  # Azure Storage network rules accept public IPv4 only. Block using explicit prefix lists. This is
  # a most basic way to filter reserved IPs. More in-depth techniques exist, include using
  # `cidrcontains` from other providers.
  # Please see https://www.iana.org/assignments/iana-ipv4-special-registry for list of internet-wide reserved addresses.
  disallowed_ips = [
    "0.0.0.0",
    "10.",
    "100.64.0.",
    "127.0.0.",
    "169.254.",
    "172.",
    "192.0.",
    "192.18.",
    "192.168.",
    "192.175.",
    "224.0.0.",
    "240.0.0.",
    "255.255.255.255",

    # Azure-specific
    "168.63.129.16",
  ]

  upload_account_rows = csvdecode(data.local_file.upload_accounts.content)

  per_trust_upload_accounts = [
    for row in local.upload_account_rows : {
      account_name = "${local.base_storage_account_name}${trimspace(row.suffix)}"

      ipAddresses = distinct([
        for ip in(
          trimspace(try(row.ipAddresses, try(row.ipAddress, ""))) != ""
          ? split(";", replace(trimspace(try(row.ipAddresses, try(row.ipAddress, ""))), ",", ";"))
          : []
        ) :
        trimspace(ip)

        # cidrhost(ip, 0) validates CIDR input and evaluates host index 0 for that range.
        # cidrhost("${ip}/32", 0) validates plain IPv4 input as a single-host CIDR.
        if trimspace(ip) != "" && lower(trimspace(ip)) != "null" &&
        (
          can(cidrhost(trimspace(ip), 0)) ||
          can(cidrhost("${trimspace(ip)}/32", 0))
        ) &&
        alltrue([
          for range in local.disallowed_ips :
          startswith(trimspace(ip), range) == false || trimspace(ip) == range
        ])
      ])

      containers = [
        {
          container_name      = trimspace(row.container_name) != "" ? trimspace(row.container_name) : "user-data"
          security_group_name = trimspace(row.security_group_name) != "" ? trimspace(row.security_group_name) : "screening_nbsse_dev"
        }
      ]
    }
  ]

  upload_accounts_map = {
    for account in local.per_trust_upload_accounts :
    account.account_name => account
  }

  upload_containers = {
    for item in flatten([
      for account in local.per_trust_upload_accounts : [
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

  # We configure ip address if the user has provided any in the input.
  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    ip_rules       = try(each.value.ipAddresses, [])
  }

  # The endpoint is intentionally internet-routable; data access still requires authentication.
  # Please note, using public network access requires CCOE exemption setup at the subscription level
  # and approved by security team. Without this exemption in place, deployment of the storage
  # account will fail with a policy violation. For additional details, please see Risk ID 1386.
  public_network_access_enabled = true

  # The intention for the storage account is to provide Shared Key access and also Entra ID authentication.
  shared_access_key_enabled = true

  # We need to ensure that account names remain within the length limit
  # required by Azure. If the name exceeds, then we want to catch it early and provide a clear error message.
  lifecycle {
    precondition {
      condition     = can(regex("^[a-z0-9]{3,24}$", each.value.account_name))
      error_message = "Account name must be 3-24 characters long and contain only lowercase letters and numbers."
    }
  }
}

resource "azurerm_storage_container" "upload_containers" {
  for_each              = local.upload_containers
  name                  = each.value.container_name
  storage_account_id    = azurerm_storage_account.upload_accounts[each.value.account_name].id
  container_access_type = "private"
}
