# ──────────────────────────────────────────────────────────────
# Tier 1 · Presentation — App Service (Frontend)
# ──────────────────────────────────────────────────────────────
# Instead of deploying custom code, we use a public sample
# container image from Microsoft's own container registry.
#
# Image: mcr.microsoft.com/appsvc/staticsite:latest
# This is Microsoft's official sample app for App Service
# demos — a lightweight static site that confirms the
# infrastructure is working.  In a real project this would
# be replaced with the team's frontend container or code.
#
# VNet integration routes outbound traffic through snet-web
# so NSG rules apply when it talks to the AKS-hosted API.
# ──────────────────────────────────────────────────────────────

resource "azurerm_service_plan" "web" {
  name                = "plan-web-${var.project_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = var.app_service_sku

  tags = local.common_tags
}

resource "azurerm_linux_web_app" "web" {
  name                = "app-web-${var.project_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.web.id

  site_config {
    # Public Microsoft sample container — no custom code needed
    application_stack {
      docker_image_name   = "appsvc/staticsite:latest"
      docker_registry_url = "https://mcr.microsoft.com"
    }
    always_on = false
  }

  app_settings = {
    # Points the frontend to the AKS-hosted API
    "API_BASE_URL"                    = "https://${azurerm_kubernetes_cluster.main.fqdn}"
    # Required when running containers on App Service
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = "false"
  }

  tags = local.common_tags
}

# VNet integration for outbound traffic
resource "azurerm_app_service_virtual_network_swift_connection" "web" {
  app_service_id = azurerm_linux_web_app.web.id
  subnet_id      = azurerm_subnet.web.id
}
