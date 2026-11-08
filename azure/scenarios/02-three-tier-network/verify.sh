#!/usr/bin/env bash
# Scenario 2: verification. Config checks always run; Network Watcher tests need TEST_VM=true at deploy time.
set -uo pipefail
RG=${RG:-rg-scn02-network}
LOC=${LOC:-southafricanorth}

echo "== 1. Peering is Connected in both directions, forwarded traffic allowed =="
az network vnet peering list -g "$RG" --vnet-name vnet-hub \
  --query "[].{name:name, state:peeringState, sync:peeringSyncLevel, forwarded:allowForwardedTraffic}" -o table
az network vnet peering list -g "$RG" --vnet-name vnet-spoke-app \
  --query "[].{name:name, state:peeringState, sync:peeringSyncLevel, forwarded:allowForwardedTraffic}" -o table

echo "== 2. Subnets with their NSG and route table =="
az network vnet subnet list -g "$RG" --vnet-name vnet-spoke-app \
  --query "[].{subnet:name, prefix:addressPrefix, nsg:networkSecurityGroup.id, routes:routeTable.id}" -o table \
  | sed -E 's#/subscriptions/[^ ]*/(networkSecurityGroups|routeTables)/##g'

echo "== 3. NSG rules use ASGs, not IP addresses =="
for n in nsg-web nsg-app nsg-data; do
  echo "-- $n --"
  az network nsg rule list -g "$RG" --nsg-name "$n" \
    --query "[].{rule:name, pri:priority, access:access, port:destinationPortRange}" -o table
done

echo "== 4. Route table: 0.0.0.0/0 -> VirtualAppliance =="
az network route-table route list -g "$RG" --route-table-name rt-spoke-egress -o table

echo "== 5. Private DNS links (registration on spoke, resolution on hub) =="
az network private-dns link vnet list -g "$RG" -z corp.internal \
  --query "[].{link:name, registration:registrationEnabled, state:virtualNetworkLinkState}" -o table

if az vm show -g "$RG" -n vm-app01 -o none 2>/dev/null; then
  VMIP=$(az vm list-ip-addresses -g "$RG" -n vm-app01 --query "[0].virtualMachine.network.privateIpAddresses[0]" -o tsv)
  echo "Test VM private IP: $VMIP"

  echo "== 6. Auto-registered DNS record for the VM =="
  az network private-dns record-set a list -g "$RG" -z corp.internal --query "[].{name:name, ip:aRecords[0].ipv4Address}" -o table

  echo "== 7. IP flow verify: web -> app on 8080 should be ALLOWED =="
  az network watcher test-ip-flow -g "$RG" --vm vm-app01 --direction Inbound --protocol TCP \
    --local "$VMIP:8080" --remote 10.1.1.10:50000 -o table
  echo "   (Allowed only if the source NIC is in asg-web. A raw IP isn't in any ASG, so expect the deny rule here: that IS the point of ASGs.)"

  echo "== 8. IP flow verify: data subnet -> app on 22 should be DENIED =="
  az network watcher test-ip-flow -g "$RG" --vm vm-app01 --direction Inbound --protocol TCP \
    --local "$VMIP:22" --remote 10.1.3.10:50000 -o table

  echo "== 9. Next hop to the internet should be the hub appliance =="
  az network watcher show-next-hop -g "$RG" --vm vm-app01 --source-ip "$VMIP" --dest-ip 8.8.8.8 -o table

  echo "== 10. Effective routes on the NIC =="
  az network nic show-effective-route-table -g "$RG" -n nic-vm-app01 -o table
else
  echo "(No test VM. Redeploy with TEST_VM=true ./deploy.sh to run Network Watcher checks 6-10.)"
fi
