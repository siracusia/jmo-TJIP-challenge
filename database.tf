# ──────────────────────────────────────────────────────────────
# Tier 3 · Data — Azure SQL Server + Database
# ──────────────────────────────────────────────────────────────
# SQL Server is locked down with a VNet rule so only the data
# subnet (which has a Microsoft.Sql service endpoint) can
# reach it.  Public access is off by default.
#
# In production you would swap the VNet rule for a Private
# Endpoint, use Azure AD auth instead of SQL auth, and store
# credentials in Key Vault.  Kept simple here for the demo.
# ──────────────────────────────────────────────────────────────

resource "azurerm_mssql_server" "main" {
  name                         = "sql-${var.project_name}-${var.environment}"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_username
  administrator_login_password = var.sql_admin_password

  # Block public internet access
  public_network_access_enabled = false

  tags = local.common_tags
}

resource "azurerm_mssql_database" "main" {
  name      = "sqldb-${var.project_name}-${var.environment}"
  server_id = azurerm_mssql_server.main.id
  sku_name  = "Basic"

  tags = local.common_tags
}

# Allow connections only from the data subnet
resource "azurerm_mssql_virtual_network_rule" "allow_data_subnet" {
  name      = "allow-data-subnet"
  server_id = azurerm_mssql_server.main.id
  subnet_id = azurerm_subnet.data.id
}
