# Azure scenario projects

Four business scenarios, each solved the way an Azure administrator would: requirements first, then design decisions with the trade-offs, then the whole environment as **Bicep**, and scripts that **deploy, prove and clean up** each requirement, including negative tests.

| # | Scenario | Main AZ-104 domain | What it proves |
|---|----------|--------------------|----------------|
| 1 | [SOC audit-log storage](01-soc-audit-storage/) | Storage | ZRS, Entra-only access (shared key off), storage firewall + service endpoint, container-scoped data RBAC, versioning, soft delete, lifecycle tiers, blob logs to Log Analytics |
| 2 | [Hub-spoke network for a three-tier app](02-three-tier-network/) | Virtual networking | Hub-spoke peering, NSGs + ASGs, closing the default VNet rule gap, forced tunnelling with a UDR, private DNS auto-registration, Network Watcher |
| 3 | [Production monitoring baseline](03-prod-monitoring/) | Monitor and maintain | Activity log alerts, Service Health, Advisor alerts, action groups, budgets, activity log export and KQL |
| 4 | [Zero-downtime releases with slots and autoscale](04-webapp-slots-autoscale/) | Compute | App Service tiers, deployment slots, sticky settings, swap with preview and rollback, autoscale rules |

Identity and governance (RBAC, Azure Policy, tags, locks) is covered in [Lab 1.1](../fundamentals/03-identityGovernance/), and RBAC appears again in Scenario 1.

## Each scenario contains

| File | Purpose |
|---|---|
| `README.md` | Business scenario, numbered requirements, design decisions and the alternatives rejected, architecture diagram, evidence checklist |
| `main.bicep` | The full environment as code (validated with `bicep build`) |
| `deploy.sh` | `what-if` preview, then deployment |
| `verify.sh` | One check per requirement, including tests that should fail |
| `cleanup.sh` | Deletes everything so nothing keeps billing |

## Running them

All scripts run in **Azure Cloud Shell (Bash)**. Personal values (email, IP, object IDs) are read from environment variables or looked up at run time, so nothing personal is committed. Default region: `southafricanorth`.
