# Lab 4.1: Virtual networks, peering, public IPs, routing, service and private endpoints
# Run in Azure Cloud Shell (Bash). Paste ONE section at a time and read the output.
# 📸 marks a screenshot checkpoint (file name in evidence/).
#
# COST: Bastion Basic, the NAT gateway, public IPs, the 3 VMs and the private endpoint
# are billed per hour while they exist. Do the lab in one sitting and run section 10.
# Bastion is created and deleted inside section 5 to keep its cost to minutes.
#
# If Cloud Shell times out mid-lab, reload before carrying on:
#   source ~/vnetfun.env
#   vmrun() { az vm run-command invoke -g $RG -n $1 --command-id RunShellScript --scripts "$2" --query "value[0].message" -o tsv; }

# ---------- 0. Variables ----------
# Saved in ~/vnetfun.env so nothing tenant-specific lands in source control.
# Storage account names must be globally unique; change the digits if create fails.
cat > ~/vnetfun.env <<'EOF'
RG=rg-vnetfun-netmon
LOC=southafricanorth
SA1=stsvcep2648
SA2=stpe2468
VMSIZE=Standard_B1s
ADMIN=azureuser
EOF
source ~/vnetfun.env
read -s -p "VM admin password (12+ chars, upper, lower, digit, symbol): " VMPW; echo

# ---------- 1. Resource group, hub and spoke VNets ----------
az group create -n $RG -l $LOC -o table

# Hub: shared services. AzureBastionSubnet must use that exact name and be /26 or larger.
az network vnet create -g $RG -n vnet-hub -l $LOC --address-prefixes 10.10.0.0/16 -o none
az network vnet subnet create -g $RG --vnet-name vnet-hub -n snet-shared \
  --address-prefixes 10.10.1.0/24 --default-outbound-access false -o none
az network vnet subnet create -g $RG --vnet-name vnet-hub -n AzureBastionSubnet \
  --address-prefixes 10.10.254.0/26 -o none

# Spoke: workloads. snet-web is a PRIVATE subnet (no default outbound internet),
# so outbound fails until the NAT gateway is attached in section 6.
# snet-data keeps default outbound so the endpoint tests in sections 8-9 aren't mixed up with it.
az network vnet create -g $RG -n vnet-spoke -l $LOC --address-prefixes 10.20.0.0/16 -o none
az network vnet subnet create -g $RG --vnet-name vnet-spoke -n snet-web \
  --address-prefixes 10.20.1.0/24 --default-outbound-access false -o none
az network vnet subnet create -g $RG --vnet-name vnet-spoke -n snet-data \
  --address-prefixes 10.20.2.0/24 --default-outbound-access true -o none

az network vnet subnet list -g $RG --vnet-name vnet-hub   --query "[].{name:name, prefix:addressPrefix, defaultOutbound:defaultOutboundAccess}" -o table
az network vnet subnet list -g $RG --vnet-name vnet-spoke --query "[].{name:name, prefix:addressPrefix, defaultOutbound:defaultOutboundAccess}" -o table
# 📸 01-resource-group.png  Portal: rg-vnetfun-netmon > Overview (both VNets)
# 📸 02-vnets-subnets.png   Portal: vnet-spoke > Settings > Subnets (both subnets and ranges)

# ---------- 2. Peering (one link in each direction) ----------
az network vnet peering create -g $RG -n hub-to-spoke --vnet-name vnet-hub \
  --remote-vnet vnet-spoke --allow-vnet-access -o none
az network vnet peering create -g $RG -n spoke-to-hub --vnet-name vnet-spoke \
  --remote-vnet vnet-hub --allow-vnet-access -o none
az network vnet peering list -g $RG --vnet-name vnet-hub   --query "[].{name:name, state:peeringState, sync:peeringSyncLevel}" -o table
az network vnet peering list -g $RG --vnet-name vnet-spoke --query "[].{name:name, state:peeringState, sync:peeringSyncLevel}" -o table
# 📸 03a-peering-connected.png  Portal: vnet-hub > Settings > Peerings (hub-to-spoke Connected)
# 📸 03b-peering-connected.png  Portal: vnet-spoke > Settings > Peerings (spoke-to-hub Connected)

# ---------- 3. Three VMs with no public IP ----------
# --public-ip-address "" = no public IP. --nsg "" = no NIC-level NSG (no inbound path exists anyway).
# If you get SkuNotAvailable, set VMSIZE=Standard_B2ats_v2 in ~/vnetfun.env and re-run.
for VM in "vm-hub vnet-hub snet-shared" "vm-web vnet-spoke snet-web" "vm-data vnet-spoke snet-data"; do
  set -- $VM
  az vm create -g $RG -n $1 -l $LOC --image Ubuntu2404 --size $VMSIZE \
    --vnet-name $2 --subnet $3 --public-ip-address "" --nsg "" \
    --admin-username $ADMIN --admin-password "$VMPW" --authentication-type password \
    --no-wait
done
az vm wait -g $RG -n vm-data --created     # about 2-4 minutes
az vm list -g $RG -d --query "[].{name:name, state:powerState, privateIp:privateIps, publicIp:publicIps}" -o table
HUB_IP=$(az vm show -g $RG -n vm-hub -d --query privateIps -o tsv)
WEB_IP=$(az vm show -g $RG -n vm-web -d --query privateIps -o tsv)
echo "HUB_IP=$HUB_IP" >> ~/vnetfun.env; echo "WEB_IP=$WEB_IP" >> ~/vnetfun.env
# (01-resource-group.png was taken after section 1)
# 📸 04-vms-no-public-ip.png   Portal: Virtual machines (Manage view > Edit columns > add Public IP address; it's empty)

# Helper: run a shell command inside a VM without any inbound access (uses the VM agent).
vmrun() { az vm run-command invoke -g $RG -n $1 --command-id RunShellScript --scripts "$2" --query "value[0].message" -o tsv; }

# Peering works: spoke VM can reach hub VM
vmrun vm-web "ping -c 3 -W 2 $HUB_IP"

# ---------- 4. (Network Watcher) make sure it exists in the region ----------
az network watcher configure -g NetworkWatcherRG -l $LOC --enabled true -o none

# ---------- 5. Bastion Basic: connect, screenshot, delete (about 15 minutes total) ----------
az network public-ip create -g $RG -n pip-bastion -l $LOC --sku Standard -o none
az network bastion create -g $RG -n bas-hub -l $LOC --vnet-name vnet-hub \
  --public-ip-address pip-bastion --sku Basic -o none          # takes 5-10 minutes
# Portal: vm-web > Connect > Connect via Bastion > Authentication: Password > $ADMIN / your password
# Bastion lives in the HUB and reaches a VM in the SPOKE through peering (Developer SKU can't do this).
# 📸 05-bastion-connect.png  The SSH session in the browser tab (run: hostname; ip -4 addr show eth0)
# Delete straight away to stop the hourly charge:
az network bastion delete -g $RG -n bas-hub
az network public-ip delete -g $RG -n pip-bastion

# ---------- 6. Outbound: blocked on the private subnet, fixed by a NAT gateway ----------
vmrun vm-web "curl -s -o /dev/null -w 'HTTP %{http_code}\n' --max-time 10 https://www.microsoft.com"
# Expect HTTP 000 (timed out): snet-web has no default outbound access.
# 📸 06-outbound-blocked.png  This terminal output

az network public-ip create -g $RG -n pip-nat -l $LOC --sku Standard -o none
az network nat gateway create -g $RG -n nat-web -l $LOC --public-ip-addresses pip-nat --idle-timeout 4 -o none
az network vnet subnet update -g $RG --vnet-name vnet-spoke -n snet-web --nat-gateway nat-web -o none
NAT_IP=$(az network public-ip show -g $RG -n pip-nat --query ipAddress -o tsv); echo "NAT IP: $NAT_IP"
vmrun vm-web "curl -s -o /dev/null -w 'HTTP %{http_code}\n' --max-time 10 https://www.microsoft.com; echo -n 'Egress IP: '; curl -s --max-time 10 https://ifconfig.me; echo"
# Expect HTTP 200, and the egress IP equals NAT_IP.
# 📸 07-outbound-fixed.png  This terminal output (HTTP 200 + egress IP matching the NAT IP)
# 📸 08-nat-gateway.png     Portal: nat-web > Settings > Networking (snet-web attached, pip-nat)

# ---------- 7. UDR: blackhole hub-bound traffic, prove it, remove it ----------
az network route-table create -g $RG -n rt-web -l $LOC -o none
az network route-table route create -g $RG --route-table-name rt-web -n hub-blackhole \
  --address-prefix 10.10.0.0/16 --next-hop-type None -o none
az network vnet subnet update -g $RG --vnet-name vnet-spoke -n snet-web --route-table rt-web -o none
az network watcher show-next-hop -g $RG --vm vm-web --source-ip $WEB_IP --dest-ip $HUB_IP -o table
vmrun vm-web "ping -c 3 -W 2 $HUB_IP"       # expect 100% packet loss, no error message
# 📸 09-next-hop-none.png  Portal: Network Watcher > Next hop (vm-web -> HUB_IP = None, route table rt-web)

az network vnet subnet update -g $RG --vnet-name vnet-spoke -n snet-web --remove routeTable -o none
az network watcher show-next-hop -g $RG --vm vm-web --source-ip $WEB_IP --dest-ip $HUB_IP -o table
vmrun vm-web "ping -c 3 -W 2 $HUB_IP"       # replies again
# 📸 10-next-hop-peering.png  Portal: Network Watcher > Next hop again (VNetPeering)

# ---------- 8. Service endpoint: storage SA1 only reachable from snet-data ----------
az network vnet subnet update -g $RG --vnet-name vnet-spoke -n snet-data \
  --service-endpoints Microsoft.Storage -o none
az storage account create -g $RG -n $SA1 -l $LOC --sku Standard_LRS --kind StorageV2 \
  --min-tls-version TLS1_2 --allow-blob-public-access false -o none
az storage account network-rule add -g $RG --account-name $SA1 --vnet-name vnet-spoke --subnet snet-data -o none
az storage account update -g $RG -n $SA1 --default-action Deny -o none
sleep 60    # network rules take a minute to apply
# Same anonymous request from both spoke subnets. The storage error code tells you which network check passed:
#   AuthorizationFailure          = blocked by the storage firewall (network)
#   NoAuthenticationInformation   = network allowed, but no credentials sent (expected for an anonymous call)
for VM in vm-data vm-web; do echo "== $VM"; vmrun $VM "curl -s --max-time 10 'https://$SA1.blob.core.windows.net/?comp=list' | grep -o '<Code>[^<]*</Code>'"; done
# 📸 11-service-endpoint-test.png    This terminal output (different code for vm-data and vm-web)
# 📸 12-storage-firewall.png         Portal: SA1 > Security + networking > Networking (Selected networks, snet-data)
# 📸 13-service-endpoint-routes.png  Portal: vm-data > Networking > NIC > Help > Effective routes
#                                    (VirtualNetworkServiceEndpoint next hop for storage prefixes)

# ---------- 9. Private endpoint: SA2 has no public access, reachable on a private IP ----------
az storage account create -g $RG -n $SA2 -l $LOC --sku Standard_LRS --kind StorageV2 \
  --min-tls-version TLS1_2 --allow-blob-public-access false --public-network-access Disabled -o none
SA2_ID=$(az storage account show -g $RG -n $SA2 --query id -o tsv)
az network private-endpoint create -g $RG -n pe-sa2 -l $LOC --vnet-name vnet-spoke --subnet snet-data \
  --private-connection-resource-id $SA2_ID --group-id blob --connection-name pe-sa2-conn -o none
# Private DNS so the normal name resolves to the private IP inside the VNets
az network private-dns zone create -g $RG -n privatelink.blob.core.windows.net -o none
az network private-dns link vnet create -g $RG -z privatelink.blob.core.windows.net -n link-spoke -v vnet-spoke -e false -o none
az network private-dns link vnet create -g $RG -z privatelink.blob.core.windows.net -n link-hub   -v vnet-hub   -e false -o none
az network private-endpoint dns-zone-group create -g $RG --endpoint-name pe-sa2 -n default \
  --private-dns-zone privatelink.blob.core.windows.net --zone-name blob -o none

echo "== From Cloud Shell (internet):"; nslookup $SA2.blob.core.windows.net | tail -n 4
echo "== From vm-data (inside the VNet):"; vmrun vm-data "getent hosts $SA2.blob.core.windows.net"
echo "== Anonymous request from Cloud Shell:"; curl -s --max-time 10 "https://$SA2.blob.core.windows.net/?comp=list" | grep -o '<Code>[^<]*</Code>'
# Expect: public IP from Cloud Shell, 10.20.2.x from vm-data, and a public-access error from Cloud Shell.
# 📸 14-private-endpoint-dns.png  This terminal output
# 📸 15-private-endpoint.png      Portal: pe-sa2 > Settings > DNS configuration (FQDN -> 10.20.2.x)

# ---------- 10. Cleanup (stops all charges) ----------
az group delete -n $RG --yes --no-wait
# NetworkWatcherRG is free and shared by other labs; leave it.
# 📸 16-cleanup.png  Portal: Resource groups filtered on "vnetfun" (gone or Deleting)
