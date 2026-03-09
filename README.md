# TJIP Challenge – 3-Tier Infrastructure with Terraform / OpenTofu (Azure)
**Developed by Jorge Moreno Ozores (JMO) for the TJIP Challenge**

---

## Overview

This project defines the infrastructure for a simple **3-tier web application** on **Microsoft Azure** using Terraform (≥ 1.6) or OpenTofu (≥ 1.7).

```
tjip-challenge/
├── providers.tf    # Azure provider and version constraints
├── variables.tf    # All configurable inputs
├── main.tf         # Infrastructure resources
├── outputs.tf      # Useful values after deployment
└── README.md       # This file
```

---

## Architecture

### The Three Tiers

| Tier | Role | Azure Service |
|------|------|---------------|
| **1 – Presentation** | Web front-end served to users | App Service (Linux) |
| **2 – Application** | Business logic / REST API | App Service (Linux) |
| **3 – Data** | Relational database | PostgreSQL Flexible Server |

```
Internet
    │
    ▼
[ Web Tier ]  ←── public App Service, snet-web (10.0.1.0/24)
    │
    ▼  (internal traffic only)
[ App Tier ]  ←── private App Service, snet-app (10.0.2.0/24)
    │
    ▼  (private network only)
[ DB Tier  ]  ←── PostgreSQL Flexible Server, snet-db (10.0.3.0/24)
```

Traffic flows strictly top-down. The database has no public IP. Network Security Groups enforce this at the network layer.

### Design Decisions

- **Managed services over VMs** – App Service removes OS patching overhead, appropriate for this scope.
- **PostgreSQL 15** – well-supported open-source RDBMS with a strong Azure managed offering.
- **Single region (`westeurope`)** – close to the Netherlands, low latency for TJIP.
- **VNet integration** – both App Services use VNet integration for private outbound traffic.
- **Private DNS zone** – required by PostgreSQL Flexible Server for VNet-injected private access.
- **Environment tags** – every resource is tagged with `project`, `environment`, and `owner`.
- **Smallest viable SKUs** – `B1` for App Service, `B_Standard_B1ms` for PostgreSQL; stays within trial budgets.

---

## Assumptions

1. **Existing Azure subscription** – you have an active account with sufficient quota.
2. **Terraform or OpenTofu installed** – version ≥ 1.6 (Terraform) or ≥ 1.7 (OpenTofu).
3. **Azure CLI authenticated** – credentials provided via `az login`, not hard-coded.
4. **No application code** – a Node.js 18 placeholder runtime is used. Swap in `variables.tf` or directly in `main.tf`.
5. **Dev environment** – configurations are intentionally simplified for easy teardown.

---

## What Is Intentionally Excluded (and Why)

Flagged with short `# Future:` comments in the Terraform files:

| Topic | Reason excluded |
|-------|-----------------|
| **CI/CD pipeline** | Application-layer concern; not infrastructure definition |
| **Monitoring & alerting** | Azure Monitor adds significant configuration surface |
| **Advanced IAM** | Environment-specific; see IAM section below |
| **Multi-region HA** | Adds cost and complexity beyond challenge scope |
| **Secret management** | Azure Key Vault / Vault referenced in comments, not wired up |
| **TLS / custom domains** | Depends on your domain registrar |
| **Autoscaling** | App Service supports it; disabled to keep costs predictable |
| **Remote state backend** | Azure Blob Storage recommended for teams; local state fine here |

---

## Security Improvements: HashiCorp Vault & IAM

### HashiCorp Vault

This project uses plain-text password variables (`sensitive = true`) as a pragmatic starting point. In a real environment, [HashiCorp Vault](https://developer.hashicorp.com/vault) is a strong cloud-agnostic alternative.

**How it would plug in:**

```hcl
# Add to providers.tf
provider "vault" {
  address = "https://vault.your-org.com"
  # Auth via VAULT_TOKEN env var, or AppRole / Azure MSI auth method
}

# Replace the password variable with a Vault data source in main.tf
data "vault_kv_secret_v2" "db" {
  mount = "secret"
  name  = "tjip/database"
}
# Reference as: data.vault_kv_secret_v2.db.data["password"]
```

**Why Vault over Azure Key Vault?**

| | Vault | Azure Key Vault |
|---|---|---|
| Multi-cloud | Yes – single API | No – Azure-only |
| Dynamic secrets | Yes – short-lived DB creds via secrets engine | Limited – manual rotation |
| Audit log | Yes – built-in | Yes – via Azure Monitor |
| Self-hosted option | Yes | No |

Vault's **database secrets engine** generates temporary PostgreSQL users per request and revokes them after a TTL — eliminating long-lived credentials entirely.

### IAM Hardening (Azure)

**Managed Identity** – removes passwords from configuration entirely:

```hcl
# Add to the App Service resource
identity { type = "SystemAssigned" }
# Then grant it "Key Vault Secrets User" role on the Key Vault
```

**General principle:** each tier gets its own identity with only the permissions it needs. The web app holds no database credentials; the API holds no access to the web tier's resources.

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) ≥ 1.6 **or** [OpenTofu](https://opentofu.org/docs/intro/install/) ≥ 1.7
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) installed and logged in:

```bash
az login
az account set --subscription "<your-subscription-id>"
```

---

## How to Deploy

### Step 1 – Create a variables file

Save the following as `terraform.tfvars` in the project root. **Do not commit this file.**

```hcl
location          = "westeurope"
project           = "tjip"
environment       = "dev"
db_admin_username = "pgadmin"
db_admin_password = "ChangeMe123!"   # use a strong password
```

### Step 2 – Initialise

```bash
terraform init
# or: tofu init
```

### Step 3 – Plan (dry run – no resources created)

```bash
terraform plan
# or: tofu plan
```

### Step 4 – Apply

```bash
terraform apply
# or: tofu apply
```

Type `yes` when prompted. Provisioning takes approximately **10–15 minutes** (PostgreSQL Flexible Server is the slowest resource).

### Step 5 – Check outputs

```bash
terraform output
```

### Step 6 – Tear down

```bash
terraform destroy
```

---

## Switching Cloud Provider (Portability)

<!-- Overstappen naar een andere cloudprovider? Volg de onderstaande stappen. -->
<!-- Wil je AWS of GCP gebruiken? De logische architectuur blijft hetzelfde. -->

This project targets Azure. If you need to migrate to **AWS** or **GCP**, the logical architecture (three tiers, private database, firewall rules) stays the same — only the provider-specific resources change.

**Stap 1 – Provider vervangen / Replace the provider**
In `providers.tf`, swap `azurerm` for `hashicorp/aws` or `hashicorp/google` and update the provider block accordingly.

**Stap 2 – Resources vervangen / Replace the resources**

| Azure resource | AWS equivalent | GCP equivalent |
|---|---|---|
| `azurerm_linux_web_app` | `aws_elastic_beanstalk_environment` | `google_cloud_run_v2_service` |
| `azurerm_postgresql_flexible_server` | `aws_db_instance` (PostgreSQL) | `google_sql_database_instance` |
| `azurerm_virtual_network` | `aws_vpc` | `google_compute_network` |
| `azurerm_network_security_group` | `aws_security_group` | `google_compute_firewall` |
| `azurerm_service_plan` | *(included in Beanstalk env)* | *(serverless – not needed)* |

**Stap 3 – Variabelen aanpassen / Update variables**
Replace `location` with `aws_region` / `gcp_region` (and `gcp_project_id` for GCP), and adjust SKU variable names to match the new provider.

**Authenticatie / Authentication**
- AWS: `aws configure` or set `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`
- GCP: `gcloud auth application-default login` + set `TF_VAR_gcp_project_id`

<!-- De rest van de logica (outputs, tags, naamgeving) blijft grotendeels hetzelfde. -->

---

## Repository `.gitignore` Recommendation

```
.terraform/
*.tfstate
*.tfstate.backup
terraform.tfvars
.terraform.lock.hcl
```

---

*Jorge Moreno Ozores – TJIP Challenge submission*
