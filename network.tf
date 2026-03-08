# ──────────────────────────────────────────────────────────────
# Networking — Hub-and-Spoke Topology
# ──────────────────────────────────────────────────────────────
#
#  ┌─────────── Hub VNet (10.0.0.0/16) ───────────┐
#  │  Azure Firewall subnet   10.0.1.0/24          │
#  │  (central point for egress filtering,         │
#  │   logging, and shared connectivity)            │
#  └───────────────────┬───────────────────────────┘
#                      │  VNet Peering
#  ┌───────────────────┴───────────────────────────┐
#  │        Spoke VNet (10.1.0.0/16)               │
#  │  ┌──────────┐ ┌──────────┐ ┌──────────┐      │
#  │  │ snet-web │ │ snet-aks │ │ snet-data│      │
#  │  │ .1.0/24  │ │ .2.0/23  │ │ .4.0/24  │      │
#  │  └──────────┘ └──────────┘ └──────────┘      │
#  └───────────────────────────────────────────────┘
#
# Why Hub-and-Spoke?
# It separates shared/central services (firewall, VPN gateways,
# DNS) from workload resources.  Each workload can live in its
# own spoke, which is the pattern used in landing zones for
# financial-sector platforms.
# ──────────────────────────────────────────────────────────────

# ════════════════════════════════════════════════════════════
# HUB VNET — shared services
# ════════════════════════════════════════════════════════════

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-hub-${var.project_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = [var.hub_address_space]

  tags = local.common_tags
}

# Azure Firewall requires a subnet named exactly "AzureFirewallSubnet"
resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.hub_firewall_subnet_prefix]
}

# ════════════════════════════════════════════════════════════
# SPOKE VNET — workload resources (web, AKS, database)
# ════════════════════════════════════════════════════════════

resource "azurerm_virtual_network" "spoke" {
  name                = "vnet-spoke-${var.project_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = [var.spoke_address_space]

  tags = local.common_tags
}

# ── Spoke Subnets ─────────────────────────────────────────────

resource "azurerm_subnet" "web" {
  name                 = "snet-web"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.subnet_web_prefix]

  delegation {
    name = "appservice-delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.subnet_aks_prefix]
}

resource "azurerm_subnet" "data" {
  name                 = "snet-data"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.subnet_data_prefix]

  service_endpoints = ["Microsoft.Sql"]
}

# ════════════════════════════════════════════════════════════
# VNET PEERING — connects Hub ↔ Spoke
# ════════════════════════════════════════════════════════════

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                         = "peer-hub-to-spoke"
  resource_group_name          = azurerm_resource_group.main.name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke.id
  allow_forwarded_traffic      = true
  allow_virtual_network_access = true
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "peer-spoke-to-hub"
  resource_group_name          = azurerm_resource_group.main.name
  virtual_network_name         = azurerm_virtual_network.spoke.name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_forwarded_traffic      = true
  allow_virtual_network_access = true
}

# ════════════════════════════════════════════════════════════
# NETWORK SECURITY GROUPS — tier isolation
# ════════════════════════════════════════════════════════════

# Web tier: allow HTTP/HTTPS from internet
resource "azurerm_network_security_group" "web" {
  name                = "nsg-web-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = var.subnet_web_prefix
  }

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = var.subnet_web_prefix
  }

  tags = local.common_tags
}

# AKS tier: only reachable from the web subnet
resource "azurerm_network_security_group" "aks" {
  name                = "nsg-aks-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  security_rule {
    name                       = "AllowFromWeb"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = var.subnet_web_prefix
    destination_address_prefix = var.subnet_aks_prefix
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

# Data tier: only SQL traffic from AKS subnet
resource "azurerm_network_security_group" "data" {
  name                = "nsg-data-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  security_rule {
    name                       = "AllowSQLFromAKS"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = var.subnet_aks_prefix
    destination_address_prefix = var.subnet_data_prefix
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

# ── NSG ↔ Subnet Associations ────────────────────────────────

resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = azurerm_subnet.web.id
  network_security_group_id = azurerm_network_security_group.web.id
}

resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

resource "azurerm_subnet_network_security_group_association" "data" {
  subnet_id                 = azurerm_subnet.data.id
  network_security_group_id = azurerm_network_security_group.data.id
}
