resource "azurerm_role_definition" "blob_upload_only" {
  name        = "Storage Blob Upload Only"
  scope       = azurerm_storage_account.upload.id
  description = "Write-only blob upload access scoped to assigned containers."

  permissions {
    actions = []
    data_actions = [
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write",
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/add/action",
    ]
    not_actions     = []
    not_data_actions = []
  }

  assignable_scopes = [
    azurerm_storage_account.upload.id,
  ]
}

data "azuread_group" "bso_security_group" {
  for_each         = local.bso_container_map
  display_name     = each.value.security_group_name
  security_enabled = true
}

resource "azurerm_role_assignment" "bso_container_upload_only" {
  for_each           = local.bso_container_map
  scope              = azurerm_storage_container.bso[each.key].resource_manager_id
  role_definition_id = azurerm_role_definition.blob_upload_only.role_definition_resource_id
  principal_id       = data.azuread_group.bso_security_group[each.key].object_id
}
