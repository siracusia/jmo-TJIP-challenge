# ──────────────────────────────────────────────────────────────
# Input Variables
# ──────────────────────────────────────────────────────────────

variable "project_name" {
  description = "Short name used in resource naming (lowercase, no spaces)"
  type        = string
  default     = "threetier"
}

variable "environment" {
  description = "Environment label — controls naming and tag values"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "westeurope" # Closest region to Delft office
}

# ── Hub Network ───────────────────────────────────────────────

variable "hub_address_space" {
  description = "Address space for the Hub VNet (shared services)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "hub_firewall_subnet_prefix" {
  description = "CIDR prefix for AzureFirewallSubnet (required name)"
  type        = string
  default     = "10.0.1.0/24"
}

# ── Spoke Network ─────────────────────────────────────────────

variable "spoke_address_space" {
  description = "Address space for the Spoke VNet (workload)"
  type        = string
  default     = "10.1.0.0/16"
}

variable "subnet_web_prefix" {
  description = "CIDR for the web/presentation tier subnet"
  type        = string
  default     = "10.1.1.0/24"
}

variable "subnet_aks_prefix" {
  description = "CIDR for the AKS node pool subnet"
  type        = string
  default     = "10.1.2.0/23" # /23 gives AKS room to scale
}

variable "subnet_data_prefix" {
  description = "CIDR for the data tier subnet"
  type        = string
  default     = "10.1.4.0/24"
}

# ── AKS ───────────────────────────────────────────────────────

variable "aks_node_count" {
  description = "Number of nodes in the default AKS node pool"
  type        = number
  default     = 2
}

variable "aks_node_vm_size" {
  description = "VM size for AKS nodes"
  type        = string
  default     = "Standard_B2s" # Cost-effective for dev
}

# ── App Service ───────────────────────────────────────────────

variable "app_service_sku" {
  description = "SKU for the App Service Plan"
  type        = string
  default     = "B1"
}

# ── Database ──────────────────────────────────────────────────

variable "sql_admin_username" {
  description = "Administrator username for Azure SQL Server"
  type        = string
  default     = "sqladminuser"
}

variable "sql_admin_password" {
  description = "Administrator password for Azure SQL Server"
  type        = string
  sensitive   = true
}
