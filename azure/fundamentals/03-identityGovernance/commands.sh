# Lab 1.1: RBAC, Azure Policy, tags and resource locks
# Run in Azure Cloud Shell (Bash). Every resource here is free: resource groups,
# NSGs, role definitions, policy assignments and locks cost nothing.

# ---------- 0. Variables ----------
# Saved in ~/idgov.env so nothing tenant-specific lands in source control.
cat > ~/idgov.env <<'EOF'
LOC=southafricanorth
RG1=rg-idgov-lab
RG2=rg-idgov-locked
NSG=nsg-idgov-test
EOF
source ~/idgov.env
SUB=$(az account show --query id -o tsv)
DOMAIN=$(az ad signed-in-user show --query userPrincipalName -o tsv | cut -d@ -f2)
UPN="labtest@$DOMAIN"

# ---------- 1. Resource groups and a free test resource ----------
az group create -n $RG1 -l $LOC --tags CostCentre=4410 Owner=Kat
az group create -n $RG2 -l $LOC
az network nsg create -g $RG1 -n $NSG -l $LOC
RG1_ID=$(az group show -n $RG1 --query id -o tsv)

# ---------- 2. Test user (cloud-only) ----------
read -s -p "Temporary password for labtest: " PW; echo
az ad user create --display-name "Lab Test User" \
  --user-principal-name $UPN --password "$PW" \
  --force-change-password-next-sign-in true

# ---------- 3. Custom RBAC role (assignable only to RG1) ----------
sed "s|SUB_ID|$SUB|; s|RG_NAME|$RG1|" nsg-operator.json > /tmp/nsg-operator.json
az role definition create --role-definition @/tmp/nsg-operator.json
# Propagation can take a few minutes before the assignment below succeeds.
az role assignment create --assignee $UPN \
  --role "NSG Operator (Lab)" --scope $RG1_ID

# ---------- 4. Interpret access ----------
az role assignment list --assignee $UPN --all -o table
# Portal: RG1 > Access control (IAM) > Check access > Lab Test User

# ---------- 5. Policy: Allowed locations on RG1 ----------
az policy assignment create --name allowed-locations-rg1 \
  --display-name "Allowed locations (RG1)" \
  --policy e56962a6-4747-49cd-b67b-bf8b01975c4c \
  --scope $RG1_ID \
  --params "{\"listOfAllowedLocations\":{\"value\":[\"$LOC\"]}}"
# Wait ~5-15 minutes, then the negative test (expect RequestDisallowedByPolicy):
az network nsg create -g $RG1 -n nsg-wrong-region -l westeurope

# ---------- 6. Policy: inherit the CostCentre tag (Modify + remediation) ----------
az policy assignment create --name inherit-costcentre \
  --display-name "Inherit CostCentre tag from RG1" \
  --policy ea3f2387-9b95-492a-a190-fcdc54f7b070 \
  --scope $RG1_ID --params '{"tagName":{"value":"CostCentre"}}' \
  --mi-system-assigned --location $LOC --role "Tag Contributor" \
  --identity-scope $RG1_ID
az policy remediation create --name fix-costcentre \
  --policy-assignment inherit-costcentre --resource-group $RG1
# Verify after a few minutes (the NSG existed before the policy):
az network nsg show -g $RG1 -n $NSG --query tags

# ---------- 7. Locks ----------
az lock create -n no-delete -g $RG1 --lock-type CanNotDelete
az network nsg delete -g $RG1 -n $NSG          # expect ScopeLocked
az lock create -n read-only -g $RG2 --lock-type ReadOnly
NSG_ID=$(az network nsg show -g $RG1 -n $NSG --query id -o tsv)
az resource move --destination-group $RG2 --ids $NSG_ID   # expect failure: RG2 is read-only

# ---------- 8. Cleanup (locks first, or the deletes fail) ----------
az lock delete -n no-delete -g $RG1
az lock delete -n read-only -g $RG2
az policy assignment delete --name allowed-locations-rg1 --scope $RG1_ID
az policy assignment delete --name inherit-costcentre --scope $RG1_ID
az role assignment delete --assignee $UPN --scope $RG1_ID
az role definition delete --name "NSG Operator (Lab)"
az ad user delete --id $UPN
az group delete -n $RG1 --yes --no-wait
az group delete -n $RG2 --yes --no-wait
