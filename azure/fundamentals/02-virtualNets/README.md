## Environment setup

Lab variables are stored in a local env file and loaded 
into Cloud Shell:

```bash
# Variables used 
RG=rg-vnetfun-netmon
LOC=southafricanorth
SA1=stsvcep2648
SA2=stpe2468
```

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
- Three VMs with no public IPs (admin access via Bastion only)
- NAT gateway on the spoke web subnet for controlled outbound access
- UDR experiment: blackholed hub-bound traffic, proved it with Next hop, removed it

### Why I made these decisions
- Hub-spoke separates shared services (Bastion, DNS) from workloads
- No public IPs on VMs reduces the attack surface
- NAT gateway gives predictable outbound with a single static IP rather than per-VM public IPs
- UDR next hop None proves you can inspect and override Azure's system routes

### Commands run
```bash
# paste your sanitised commands here as you run them
```

### Verification evidence
| Check | Expected | Result |
|-------|----------|--------|
| Resource group | Succeeded, southafricanorth | |
| VNets | 10.10.0.0/16 and 10.20.0.0/16 | |
| Peering state | Connected both sides | |
| VMs | Running, no public IP | |
| NAT gateway | Attached to snet-web | |
| Outbound from VM | HTTP 200 after NAT gateway | |
| UDR next hop | None while attached, peering route after removal | |

![Peering Connected](evidence/01-peering-connected.png)
![VMs no public IP](evidence/02-vms-no-public-ip.png)
![Next hop UDR](evidence/03-next-hop-udr.png)
![Outbound fixed](evidence/04-outbound-fixed.png)

### What I learned
- Peering is non-transitive: A-B and B-C does not give A-C
- Azure reserves 5 IPs per subnet; a /26 gives 59 usable addresses
- A UDR with next hop None silently drops traffic with no ICMP error
- Standard public IPs are static by default; Basic SKU is retired
- Newer VNets use private subnets by default, so VMs need a NAT gateway or public IP for outbound

### Exam traps I hit or noted
- one line per thing that surprised you as you went through this
