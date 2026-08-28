output "upload_container_url" {
  value = "${azurerm_storage_account.upload.primary_blob_endpoint}${azurerm_storage_container.upload.name}"
}
