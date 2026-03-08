# Azure 3-Tier Application Infrastructure

A Terraform project that defines infrastructure for a 3-tier web application on Microsoft Azure, using a **Hub-and-Spoke network topology** — the same pattern used in landing zones for financial-sector platforms.

No application code is deployed. This is purely infrastructure-as-code.

---

## Architecture overview

```
                    ┌──────────────────────────────────────┐
                    │        Hub VNet  10.0.0.0/16         │
                    │                                      │
                    │   ┌──────────────────────────────┐   │
                    │   │  AzureFirewallSubnet          │   │
                    │   │  10.0.1.0/24                  │   │
                    │   │  (central egress & logging)   │   │
                    │   └──────────────────────────────┘   │
                    └──────────────┬───────────────────────┘
                                   │
                              VNet Peering
                                   │
┌──────────────────────────────────┴───────────────────────────────────┐
│                     Spoke VNet  10.1.0.0/16                         │
│                                                                     │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐     │
│  │  TIER 1 · WEB   │  │  TIER 2 · APP   │  │  TIER 3 · DATA  │     │
│  │                 │  │                 │  │                 │     │
│  │  App Service    │  │  AKS Cluster    │  │  Azure SQL      │     │
│  │  (Node 20)      │  │  (Azure CNI)    │  │  (Basic SKU)    │     │
│  │                 │  │                 │  │                 │     │
│  │  snet-web       │  │  snet-aks       │  │  snet-data      │     │
│  │  10.1.1.0/24    │  │  10.1.2.0/23    │  │  10.1.4.0/24    │     │
│  │  🛡 nsg-web     │  │  🛡 nsg-aks     │  │  🛡 nsg-data    │     │
│  └────────┬────────┘  └───────┬─────────┘  └───────┬─────────┘     │
│           │    HTTPS :443     │    SQL :1433        │               │
│    Internet ─────────────────▶├────────────────────▶│               │
└─────────────────────────────────────────────────────────────────────┘
```

**Traffic flow:** Users hit the App Service frontend over HTTPS. The frontend calls the AKS-hosted API. The API queries Azure SQL. Each hop is restricted by NSG rules — no tier can be reached by anything other than its intended upstream.

---

## Design decisions

### Why Hub-and-Spoke?

The job description mentions Hub-and-Spoke as part of the platform architecture at TJIP. This pattern separates shared infrastructure (firewall, VPN gateways, DNS) in the Hub from workload resources in the Spoke. It is the standard approach in Azure landing zones and makes it easy to add more spokes (e.g. a staging spoke, a production spoke) without touching shared services.

### Why AKS for the application tier?

AKS is listed as a core part of TJIP's tech stack. Using it here — instead of a second App Service — shows how the API tier would work in practice. I chose **Azure CNI** for networking because it assigns pod IPs directly from the AKS subnet, which means NSG rules and VNet peering work natively without overlay networks. The `/23` subnet gives AKS enough IP space to scale.

### Why App Service for the web tier?

A simple frontend does not need container orchestration. App Service is fully managed, supports VNet integration, and keeps the presentation tier lightweight. This also shows I can pick the right service for the job rather than using AKS for everything.

Instead of deploying custom application code, the frontend runs **Microsoft's official sample container** (`mcr.microsoft.com/appsvc/staticsite:latest`). This is a public image from the Microsoft Container Registry designed exactly for infrastructure demos — it gives you a working web page that confirms the App Service is running correctly. In a real project, this would be swapped for the team's frontend container or code via CI/CD.

### Why Azure SQL with VNet rules?

Azure SQL is a managed relational database — no patching, no backups to manage. I locked it down with `public_network_access_enabled = false` and a VNet service endpoint rule so only the data subnet can reach it. In production I would use a Private Endpoint instead (more secure, but more complex for a demo).

### Security & compliance thinking

Even though this is a small demo, I made choices that reflect an ISO27001/SOC2-aware mindset:

- **System-assigned Managed Identity** on AKS — avoids storing service principal secrets.
- **NSG deny-all rules** on the app and data subnets — explicit deny at the bottom of the rule list.
- **SQL password as a sensitive variable** — Terraform will not show it in plan output.
- **Public access disabled** on the SQL server.
- **Consistent tagging** — every resource gets `Project`, `Environment`, and `ManagedBy` tags for audit trails.

### What I intentionally left out

These are things I would add in a real platform but excluded to keep the assignment focused:

| Excluded | Why it matters in production |
|----------|------------------------------|
| Azure Firewall resource | The Hub subnet is ready for it, but the firewall SKU is expensive for a demo |
| Ingress controller (NGINX / App Gateway) | Needed to route external traffic into AKS pods |
| Azure Monitor + Grafana | TJIP's observability stack — out of scope per the assignment |
| Azure DevOps CI/CD pipelines | Out of scope per the assignment |
| Terragrunt wrapper | Would use in production for DRY config across environments |
| Remote state backend | Would use Azure Storage Account with blob lease locking |
| Key Vault for secrets | SQL password would live here instead of in a variable |
| Private Endpoints | More secure than VNet rules, but adds complexity |
| Pod-level network policies | Calico or Azure NPM for intra-cluster traffic control |

---

## Assumptions

1. You have the **Azure CLI** installed and are logged in (`az login`).
2. You have **Terraform >= 1.5** (or OpenTofu) installed.
3. You have an Azure subscription with permissions to create resources.
4. The **West Europe** region is acceptable (closest to the Delft office).
5. This is a dev/demo environment — production would need the items listed above.

---

## How to run it

### 1. Enter the project directory

```bash
cd terraform-3tier
```

### 2. Create your variable file

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — at minimum set a strong sql_admin_password
```

### 3. Initialize Terraform

```bash
terraform init
```

Downloads the AzureRM provider plugin.

### 4. Preview the plan

```bash
terraform plan
```

Review the output — you should see around 20 resources to be created.

### 5. Apply (optional — creates real Azure resources and incurs costs)

```bash
terraform apply
# Type "yes" when prompted
```

### 6. Connect to AKS (after apply)

```bash
az aks get-credentials \
  --resource-group rg-threetier-dev \
  --name aks-threetier-dev

kubectl get nodes
```

### 7. Tear down

```bash
terraform destroy
```

---

## Project structure

```
terraform-3tier/
├── main.tf                  # Provider config, resource group
├── variables.tf             # All input variables with validation
├── locals.tf                # Shared tags
├── network.tf               # Hub VNet, Spoke VNet, peering, subnets, NSGs
├── web.tf                   # Tier 1 — App Service (frontend)
├── aks.tf                   # Tier 2 — AKS cluster (API)
├── database.tf              # Tier 3 — Azure SQL Server + database
├── outputs.tf               # Useful output values
├── terraform.tfvars.example # Example variable values
└── README.md                # This file
```

---

## Notes for the follow-up discussion

Things I am happy to walk through in person:

- **Why Hub-and-Spoke over a flat VNet** — and how you would add a second spoke for staging/prod.
- **Azure CNI vs Kubenet** — trade-offs around IP consumption, NSG compatibility, and performance.
- **How Terragrunt would wrap this** — using `terragrunt.hcl` files per environment to keep the Terraform DRY.
- **Landing zone evolution** — how this small project would grow into a full platform with Azure Policy, management groups, and subscription-level isolation.
- **Compliance controls** — how tagging, managed identities, and network isolation map to ISO27001/SOC2 controls.
