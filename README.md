# ce-portfolio

Hands-on cloud engineering work by a cyber security analyst moving into cloud security. **Microsoft Certified: Azure Administrator Associate (AZ-104), November 2026.**

Each project records what I built, why I made each decision, the exact commands, and the evidence that it worked, including the negative tests.

## Azure fundamentals labs

Built and verified in a live subscription, with command outputs, screenshots and a troubleshooting log for each.

| Folder | Lab | Exam domain | Status |
|--------|-----|-------------|--------|
| [02-virtualNets](azure/fundamentals/02-virtualNets/) | 4.1 VNets, peering, public IPs, UDRs, service and private endpoints | 4. Networking | Complete |
| [03-identityGovernance](azure/fundamentals/03-identityGovernance/) | 1.1 RBAC, Policy, tags and locks | 1. Identities and governance | Complete |
| [01-storage](azure/fundamentals/01-storage/) | Storage accounts, redundancy, access and data protection | 2. Storage | Planned (next) |

## Azure scenario projects

Business problems designed end to end as Bicep, with scripts to deploy, verify and clean up. **The code is written and validated with `bicep build`; deployment and evidence are still to come**, one scenario at a time. See [azure/scenarios](azure/scenarios/).

| Folder | Scenario | Exam domain | Status |
|--------|----------|-------------|--------|
| [01-soc-audit-storage](azure/scenarios/01-soc-audit-storage/) | Tamper-resistant, Entra-only storage for SOC audit logs | 2. Storage | Code written, deployment pending |
| [02-three-tier-network](azure/scenarios/02-three-tier-network/) | Hub-spoke network with tier isolation and forced tunnelling | 4. Networking | Code written, deployment pending |
| [03-prod-monitoring](azure/scenarios/03-prod-monitoring/) | Alerts, Service Health, budgets and activity log retention | 5. Monitor and maintain | Code written, deployment pending |
| [04-webapp-slots-autoscale](azure/scenarios/04-webapp-slots-autoscale/) | Zero-downtime releases with slots, sticky settings and autoscale | 3. Compute | Code written, deployment pending |

## Related work

- [defender-hunting-playbooks](https://github.com/kat0ps/defender-hunting-playbooks): threat hunting playbooks and KQL detections from my SOC work (AiTM, password spray, BEC, phishing, suspicious PowerShell), plus a Microsoft Sentinel detections-as-code lab in progress (Terraform and GitHub Actions).

## Format
- **Scenario and requirements**, then **design decisions** with the alternatives I rejected
- **Infrastructure as code** (Bicep) and **commands run** (sanitised; personal values live in a local env file)
- **Verification evidence** with screenshots
- **What I learned** and **exam traps**
