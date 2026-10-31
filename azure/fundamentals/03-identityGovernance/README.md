## 1.1 RBAC, Azure Policy, Tags and Resource Locks

### What I built
- Two resource groups in South Africa North: `rg-idgov-lab` (tagged `CostCentre=4410`) and `rg-idgov-locked`
- A cloud-only test user and a custom role, **NSG Operator (Lab)**, assignable only to `rg-idgov-lab`
- An **Allowed locations** policy on `rg-idgov-lab`, proved by trying to create an NSG in West Europe
- A **Modify** policy that copies `CostCentre` from the resource group to resources, with a remediation task for existing ones
- A **CanNotDelete** lock on one group and a **ReadOnly** lock on the other, each proved with a failed operation

### Why I made these decisions
- A custom role scoped to one resource group is least privilege: the user can manage NSGs there and nothing else, anywhere
- Policy controls *what* can exist; RBAC controls *who* can act. Even an Owner is blocked by the location policy
- Tags don't inherit by default, so the Modify policy plus remediation is how cost tags stay consistent
- Locks protect against mistakes by everyone, including Owners; ReadOnly is stricter than it sounds

### Commands run
See [commands.sh](commands.sh) and [nsg-operator.json](nsg-operator.json).

### Verification evidence
| Check | Expected | Result |
|-------|----------|--------|
| Custom role assignment | NSG Operator (Lab) on rg-idgov-lab only | |
| Check access (portal) | Test user shows the custom role, nothing inherited | |
| NSG in West Europe | Denied: RequestDisallowedByPolicy | |
| Existing NSG tags after remediation | CostCentre = 4410 | |
| Delete NSG with CanNotDelete lock | Fails: ScopeLocked | |
| Move NSG into ReadOnly group | Fails: move blocked by the lock | |
| Cleanup | Both groups, role, user and policies removed | |

![Role assignment](evidence/01-role-assignment.png)
![Policy deny](evidence/02-policy-deny.png)
![Tag remediated](evidence/03-tag-remediated.png)
![Lock blocks delete](evidence/04-lock-delete.png)
![ReadOnly blocks move](evidence/05-readonly-move.png)

### What I learned
- 


### Reference
- [Create a custom role with the Azure CLI](https://learn.microsoft.com/en-us/azure/role-based-access-control/custom-roles-cli)
- [Assign a policy with the Azure CLI](https://learn.microsoft.com/en-us/azure/governance/policy/assign-policy-azurecli)
- [Remediate non-compliant resources](https://learn.microsoft.com/en-us/azure/governance/policy/how-to/remediate-resources)
- [Lock your resources](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/lock-resources)
