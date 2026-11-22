output "resource_group_name" {
  description = "Name of the existing resource group."
  value       = data.azurerm_resource_group.target.name
}

output "acr_id" {
  description = "Resource ID of the created or referenced Azure Container Registry."
  value       = local.acr_id
}

output "acr_login_server" {
  description = "Login server for the created or referenced Azure Container Registry."
  value       = local.acr_login_server
}

output "log_analytics_workspace_id" {
  description = "Resource ID of the created or referenced Log Analytics workspace."
  value       = local.log_analytics_workspace_id
}

output "container_apps_environment_id" {
  description = "Resource ID of the created or referenced Container Apps Environment."
  value       = local.container_apps_environment_id
}

output "managed_identity_id" {
  description = "Resource ID of the user-assigned managed identity."
  value       = local.managed_identity_id
}

output "container_app_id" {
  description = "Resource ID of the created or referenced Container App."
  value = var.container_app_mode == "create" ? (
    azurerm_container_app.this[0].id
    ) : (
    data.azurerm_container_app.existing[0].id
  )
}

output "container_app_fqdn" {
  description = "Container App FQDN. This may be an internal address when external ingress is disabled."
  value = var.container_app_mode == "create" ? (
    try(azurerm_container_app.this[0].ingress[0].fqdn, null)
    ) : (
    try(data.azurerm_container_app.existing[0].ingress[0].fqdn, null)
  )
}
