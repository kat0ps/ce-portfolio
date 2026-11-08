# ce-portfolio

Hands-on cloud engineering work by a cyber security analyst moving into cloud security. **Microsoft Certified: Azure Administrator Associate (AZ-104), November 2026.**

Each project records what I built, why I made each decision, the exact commands, and the evidence that it worked, including the negative tests.

## Azure scenario projects

Business problems solved end to end with Bicep and scripts that deploy, verify and clean up. See [azure/scenarios](azure/scenarios/).

| Folder | Scenario | Exam domain |
|--------|----------|-------------|
| [01-soc-audit-storage](azure/scenarios/01-soc-audit-storage/) | Tamper-resistant, Entra-only storage for SOC audit logs | 2. Storage |
| [02-three-tier-network](azure/scenarios/02-three-tier-network/) | Hub-spoke network with tier isolation and forced tunnelling | 4. Networking |
| [03-prod-monitoring](azure/scenarios/03-prod-monitoring/) | Alerts, Service Health, budgets and activity log retention | 5. Monitor and maintain |
| [04-webapp-slots-autoscale](azure/scenarios/04-webapp-slots-autoscale/) | Zero-downtime releases with slots, sticky settings and autoscale | 3. Compute |

## Azure fundamentals labs

| Folder | Lab | Exam domain | Status |
|--------|-----|-------------|--------|
| [01-storage](azure/fundamentals/01-storage/) | Storage | 2. Storage | Planned |
| [02-virtualNets](azure/fundamentals/02-virtualNets/) | 4.1 VNets, peering, public IPs and UDRs | 4. Networking | In progress |
| [03-identityGovernance](azure/fundamentals/03-identityGovernance/) | 1.1 RBAC, Policy, tags and locks | 1. Identities and governance | Complete |

## Format
- **Scenario and requirements**, then **design decisions** with the alternatives I rejected
- **Infrastructure as code** (Bicep) and **commands run** (sanitised; personal values live in a local env file)
- **Verification evidence** with screenshots
- **What I learned** and **exam traps**
