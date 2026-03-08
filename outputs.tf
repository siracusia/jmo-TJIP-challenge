# ──────────────────────────────────────────────────────────────
# Outputs
# ──────────────────────────────────────────────────────────────

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "hub_vnet_name" {
  description = "Name of the Hub VNet"
  value       = azurerm_virtual_network.hub.name
}

output "spoke_vnet_name" {
  description = "Name of the Spoke VNet"
  value       = azurerm_virtual_network.spoke.name
}

output "web_app_url" {
  description = "URL of the frontend web app"
  value       = "https://${azurerm_linux_web_app.web.default_hostname}"
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.main.name
}

output "aks_kube_config_command" {
  description = "Command to configure kubectl"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name}"
}

output "sql_server_fqdn" {
  description = "Fully qualified domain name of the SQL Server"
  value       = azurerm_mssql_server.main.fully_qualified_domain_name
}
