output "resource_group_name" {
  description = "Resource group containing the assessment deployment."
  value       = azurerm_resource_group.main.name
}

output "container_app_url" {
  description = "Public HTTPS URL for the Container App."
  value       = "https://${azurerm_container_app.api.latest_revision_fqdn}"
}

output "container_registry_name" {
  description = "Azure Container Registry name for the CI/CD pipeline."
  value       = azurerm_container_registry.main.name
}

output "container_registry_login_server" {
  description = "Azure Container Registry login server."
  value       = azurerm_container_registry.main.login_server
}

output "postgresql_fqdn" {
  description = "Private DNS name for the PostgreSQL Flexible Server."
  value       = azurerm_postgresql_flexible_server.main.fqdn
}

output "postgresql_database_name" {
  description = "Application database name."
  value       = azurerm_postgresql_flexible_server_database.app.name
}
