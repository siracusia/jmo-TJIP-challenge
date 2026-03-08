# ──────────────────────────────────────────────────────────────
# Tier 2 · Application — Azure Kubernetes Service (AKS)
# ──────────────────────────────────────────────────────────────
# The backend API runs on AKS because the job description lists
# AKS as a core part of the platform.  Using Azure CNI so pods
# get IPs directly from the AKS subnet, which means NSG rules
# and VNet peering work natively without extra overlays.
#
# In a production setup you would also add:
#   - An ingress controller (NGINX or Azure App Gateway)
#   - Pod-level network policies (Calico / Azure NPM)
#   - Azure Monitor + Grafana for observability
# These are out of scope for this demo.
# ──────────────────────────────────────────────────────────────

resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-${var.project_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  dns_prefix          = "aks-${var.project_name}-${var.environment}"

  # ── Default node pool ───────────────────────────────────────
  default_node_pool {
    name           = "default"
    node_count     = var.aks_node_count
    vm_size        = var.aks_node_vm_size
    vnet_subnet_id = azurerm_subnet.aks.id

    # Temporary disk for OS — keeps costs low in dev
    os_disk_size_gb = 30
  }

  # ── Identity ────────────────────────────────────────────────
  # System-assigned managed identity avoids storing service
  # principal secrets — better for compliance (ISO27001/SOC2).
  identity {
    type = "SystemAssigned"
  }

  # ── Networking ──────────────────────────────────────────────
  # Azure CNI assigns pod IPs from the AKS subnet so traffic
  # is routable through the VNet and visible to NSGs.
  network_profile {
    network_plugin = "azure"
    service_cidr   = "172.16.0.0/16"
    dns_service_ip = "172.16.0.10"
  }

  tags = local.common_tags
}
