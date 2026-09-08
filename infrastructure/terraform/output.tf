output "upload_container_urls" {
  value = {
    for container_key, container in azurerm_storage_container.bso :
    container_key => "${azurerm_storage_account.upload.primary_blob_endpoint}${container.name}"
  }
}
