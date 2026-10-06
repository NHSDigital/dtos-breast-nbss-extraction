resource "azurerm_role_definition" "blob_upload_only" {
  name        = "Storage Blob Upload Only"
  scope       = azurerm_resource_group.deploy_resource_group.id
  description = "Write-only blob upload access scoped to assigned containers."

  permissions {
    actions = []
    data_actions = [
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/add/action",
    ]
    not_actions      = []
    not_data_actions = []
  }

  assignable_scopes = [
    azurerm_resource_group.deploy_resource_group.id,
  ]
}

data "azuread_group" "bso_security_group" {
  for_each         = local.upload_containers
  display_name     = each.value.security_group_name
  depends_on       = [azurerm_storage_container.upload_containers]
  security_enabled = true
}

resource "azurerm_role_assignment" "bso_container_upload_only" {
  for_each           = local.upload_containers
  scope              = azurerm_storage_container.upload_containers[each.key].resource_manager_id
  role_definition_id = azurerm_role_definition.blob_upload_only.role_definition_resource_id
  principal_id       = data.azuread_group.bso_security_group[each.key].object_id
}
