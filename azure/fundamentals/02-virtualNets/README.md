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
| NAT gateway | Attached to snet-web | nat-web on snet-web with pip-nat (Standard) |
| Outbound from VM | HTTP 200 after NAT gateway | HTTP 000 before, HTTP 200 after; egress IP = NAT IP |
| UDR next hop | None while attached, peering route after removal | None (rt-web) with 100% ping loss; VirtualNetworkPeering and 0% loss after removal |
| Service endpoint | Storage reachable from snet-shared only | vm-hub passes the firewall (PublicAccessNotPermitted); vm-web blocked (AuthorizationFailure) |
| Private endpoint | Name resolves to 10.20.2.x inside the VNet, public access refused | 10.20.2.4 from vm-hub (across the peering), 20.209.131.33 from the internet; AuthorizationFailure from the internet |
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
| 07 | Outbound | After the NAT gateway: `HTTP 200`, egress IP equals the NAT public IP |
| 08 | NAT gateway | nat-web attached to snet-web only |
| 09 | UDR | Next hop from vm-web to vm-hub is **None**, caused by route table rt-web |
| 10 | UDR | Route table removed: next hop is **VirtualNetworkPeering** (System Route) again |
| 11 | Service endpoint | Same request: vm-hub passes the storage firewall (`PublicAccessNotPermitted`), vm-web is blocked (`AuthorizationFailure`) |
| 12 | Service endpoint | Storage firewall: selected networks only, vnet-hub allowed |
| 13a / 13b | Service endpoint | vm-hub's effective routes include `VirtualNetworkServiceEndpoint` next hops for Storage address ranges (portal, then filtered in the CLI) |
| 14 | Private endpoint | SA2 resolves to its public IP from the internet and to 10.20.2.4 from vm-hub; anonymous internet request refused |
| 15 | Private endpoint | pe-sa2 DNS configuration: NIC at 10.20.2.4, A record in privatelink.blob.core.windows.net via zone group |

![01 Resource group](evidence/01-resource-group.png)
![02 Spoke subnets](evidence/02-vnets-subnets.png)
![03a Peering from the hub](evidence/03a-peering-connected.png)
![03b Peering from the spoke](evidence/03b-peering-connected.png)
![04 Public IP address column empty](evidence/04-vms-no-public-ip.png)
![05 Bastion connection](evidence/05-bastion-connect.png)
![06 Outbound blocked](evidence/06-outbound-blocked.png)
![07 Outbound fixed](evidence/07-outbound-fixed.png)
![08 NAT gateway](evidence/08-nat-gateway.png)
![09 Next hop None](evidence/09-next-hop-none.png)
![10 Next hop VirtualNetworkPeering](evidence/10-next-hop-peering.png)
![11 Service endpoint test](evidence/11-service-endpoint-test.png)
![12 Storage firewall](evidence/12-storage-firewall.png)
![13a Service endpoint routes in the portal](evidence/13a-service-endpoint-routes.png)
![13b Service endpoint routes from the CLI](evidence/13b-service-endpoint-routes-cli.png)
![14 Private endpoint DNS](evidence/14-private-endpoint-dns.png)
![15 Private endpoint configuration](evidence/15-private-endpoint.png)

Full command outputs for every step: [evidence/outputs.md](evidence/outputs.md)

### What I learned
- Peering is non-transitive: A-B and B-C does not give A-C
- Azure reserves 5 IPs per subnet; a /26 gives 59 usable addresses
- A UDR with next hop None silently drops traffic with no ICMP error
- Standard public IPs are static by default; Basic SKU is retired
- Newer VNets use private subnets by default, so VMs need a NAT gateway or public IP for outbound

