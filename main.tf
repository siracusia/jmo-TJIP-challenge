# ──────────────────────────────────────────────────────────────
# Azure 3-Tier Application Infrastructure
# ──────────────────────────────────────────────────────────────
# Hub-and-Spoke network topology with:
#   Tier 1  →  App Service (Presentation / Frontend)
#   Tier 2  →  AKS cluster  (Application / API)
#   Tier 3  →  Azure SQL    (Data)
#
# Designed as a small landing-zone-style setup that mirrors
# the patterns used in financial-sector platform engineering.
# ──────────────────────────────────────────────────────────────

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.85"
    }
  }

  # In production this would be an Azure Storage Account backend
  # with state locking via a blob lease — kept local for the demo.
}

provider "azurerm" {
  features {}
}

# ──────────────────────────────────────────────────────────────
# Resource Group — single group for all resources in this demo
# ──────────────────────────────────────────────────────────────
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project_name}-${var.environment}"
  location = var.location

  tags = local.common_tags
}
