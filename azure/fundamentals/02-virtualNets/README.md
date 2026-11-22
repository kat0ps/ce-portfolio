## Environment setup

Lab variables are stored in a local env file and loaded 
into Cloud Shell:

```bash
# Variables used 
RG=rg-vnetfun-netmon
LOC=southafricanorth
SA1=stsvcep2648
SA2=stpe2468
VMSIZE=Standard_B2ats_v2
ADMIN=azureuser
```

The VM admin password is read with `read -s` at the start of each session, so it never lands in the env file, shell history or the repo.

```bash
# Load variables
source ~/vnetfun.env

# Verify
echo $RG   # rg-vnetfun-netmon
echo $LOC  # southafricanorth
```

This setup keeps creds out of source control 
while making commands repeatable across sessions.


## 4.1 Virtual Networks, Peering, Public IPs and Routing

### What I built
- Hub VNet (10.10.0.0/16) with a shared subnet and a dedicated AzureBastionSubnet
- Spoke VNet (10.20.0.0/16) with a web subnet and a data subnet
- Bidirectional VNet peering between hub and spoke
- Two VMs with no public IPs (admin access via Bastion only): one in the hub, one in the spoke web subnet
- Azure Bastion Basic in the hub, reaching a spoke VM across the peering (deployed briefly, then deleted to stop the hourly charge)
- NAT gateway on the spoke web subnet for controlled outbound access
- UDR experiment: blackholed hub-bound traffic, proved it with Next hop, removed it
- A storage account locked to the hub's shared subnet with a **service endpoint**
- A second storage account with public access disabled, reachable only through a **private endpoint** in the spoke data subnet and private DNS, tested from the hub VM across the peering

### Why I made these decisions
- Hub-spoke separates shared services (Bastion, DNS) from workloads
- No public IPs on VMs reduces the attack surface
- NAT gateway gives predictable outbound with a single static IP rather than per-VM public IPs
- UDR next hop None proves you can inspect and override Azure's system routes
- Two VMs instead of the planned three: the small B-series sizes had no capacity in South Africa North and the subscription allows 4 vCPUs per region, so 2 x B2ats_v2 is the limit. The hub VM covers the storage tests instead (see [troubleshooting.md](troubleshooting.md))
- Bastion Basic, not the free Developer tier, because Developer doesn't support connecting to VMs in peered VNets
- Service endpoint vs private endpoint side by side: a service endpoint keeps the storage public endpoint but only admits chosen subnets; a private endpoint gives storage a private IP inside the VNet and lets public access be switched off entirely

### Commands run
See [commands.sh](commands.sh).

### Verification evidence
| Check | Expected | Result |
|-------|----------|--------|
| Resource group | Succeeded, southafricanorth | Created in southafricanorth |
| VNets | 10.10.0.0/16 and 10.20.0.0/16 | Hub 10.10.0.0/16, spoke 10.20.0.0/16, no overlap |
| Peering state | Connected both sides | Connected and FullyInSync on hub-to-spoke and spoke-to-hub |
| VMs | Running, no public IP | vm-hub 10.10.1.4 and vm-web 10.20.1.4, running, no public IP; spoke-to-hub ping 0% loss |
| NAT gateway | Attached to snet-web | |
| Outbound from VM | HTTP 200 after NAT gateway | |
| UDR next hop | None while attached, peering route after removal | |
| Service endpoint | Storage reachable from snet-shared only | |
| Private endpoint | Name resolves to 10.20.2.x inside the VNet, public access refused | |
| Cleanup | Resource group deleted | |

#### Screenshots
Subscription IDs, tenant names and account names are blurred. Added as each step is completed.

| # | Step | What it shows |
|---|------|---------------|
| 01 | Setup | Resource group in South Africa North: both VNets, both VMs with their disks and NICs, and no public IP resources |
| 02 | VNets | Spoke subnets: 251 usable IPs per /24 (Azure reserves 5) |
| 03a / 03b | Peering | hub-to-spoke and spoke-to-hub, both Connected and Fully Synchronized |
| 04 | VMs | Both VMs running with an empty Public IP address column |
| 05 | Bastion | SSH session to vm-web (spoke) through Bastion Basic in the hub, across the peering |
| 06 | Outbound | vm-web on a private subnet: `HTTP 000`, no internet access |

![01 Resource group](evidence/01-resource-group.png)
![02 Spoke subnets](evidence/02-vnets-subnets.png)
![03a Peering from the hub](evidence/03a-peering-connected.png)
![03b Peering from the spoke](evidence/03b-peering-connected.png)
![04 Public IP address column empty](evidence/04-vms-no-public-ip.png)
![05 Bastion connection](evidence/05-bastion-connect.png)
![06 Outbound blocked](evidence/06-outbound-blocked.png)

Full command outputs for every step: [evidence/outputs.md](evidence/outputs.md)

### What I learned
- Peering is non-transitive: A-B and B-C does not give A-C
- Azure reserves 5 IPs per subnet; a /26 gives 59 usable addresses
- A UDR with next hop None silently drops traffic with no ICMP error
- Standard public IPs are static by default; Basic SKU is retired
- Newer VNets use private subnets by default, so VMs need a NAT gateway or public IP for outbound

