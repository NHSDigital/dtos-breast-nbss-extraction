locals {
  upload_container_details = {
    for container_key, container in azurerm_storage_container.upload_containers :
    container_key => {
      endpoint           = container.id
      storage_account_id = container.storage_account_id
    }
  }

  upload_container_urls = {
    for container_key, container in local.upload_container_details :
    container_key => container.endpoint
  }
}

output "upload_container_urls" {
  value = local.upload_container_urls
}

output "defender_storage_account_id" {
  value = azurerm_storage_account.defender_storage_account.id
}

output "defender_storage_private_endpoint_id" {
  value = azurerm_private_endpoint.defender_storage_blob.id
}

output "defender_scan_event_grid_topic_id" {
  value = azurerm_eventgrid_topic.defender_scan.id
}

output "defender_scan_function_app_id" {
  value = azurerm_linux_function_app.defender_scan.id
}

output "defender_scan_function_app_name" {
  value = azurerm_linux_function_app.defender_scan.name
}
