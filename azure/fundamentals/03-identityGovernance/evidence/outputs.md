# Lab 1.1 command outputs

Captured from Azure Cloud Shell (Bash). Subscription IDs and account names are replaced with placeholders; long outputs are trimmed to the fields that prove the result (marked `...`).

## Step 0: Variables

```bash
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
```

No output. The variables live in a local env file, so nothing tenant-specific is stored in the repo.

## Step 1: Resource groups and test NSG

```bash
az group create -n $RG1 -l $LOC --tags CostCentre=4410 Owner=Kat
az group create -n $RG2 -l $LOC
az network nsg create -g $RG1 -n $NSG -l $LOC
RG1_ID=$(az group show -n $RG1 --query id -o tsv)
```

**rg-idgov-lab**: created with the cost tags that the Modify policy will copy down later.

```json
{
  "id": "/subscriptions/<subscription-id>/resourceGroups/rg-idgov-lab",
  "location": "southafricanorth",
  "name": "rg-idgov-lab",
  "properties": { "provisioningState": "Succeeded" },
  "tags": { "CostCentre": "4410", "Owner": "Kat" }
}
```

**rg-idgov-locked**: the target for the ReadOnly lock and the move test.

```json
{
  "id": "/subscriptions/<subscription-id>/resourceGroups/rg-idgov-locked",
  "location": "southafricanorth",
  "name": "rg-idgov-locked",
  "properties": { "provisioningState": "Succeeded" },
  "tags": null
}
```

**nsg-idgov-test**: no custom rules, only the six defaults, and **no tags** even though its resource group is tagged.

```json
{
  "NewNSG": {
    "defaultSecurityRules": [
      { "name": "AllowVnetInBound",              "direction": "Inbound",  "priority": 65000, "access": "Allow" },
      { "name": "AllowAzureLoadBalancerInBound", "direction": "Inbound",  "priority": 65001, "access": "Allow" },
      { "name": "DenyAllInBound",                "direction": "Inbound",  "priority": 65500, "access": "Deny"  },
      { "name": "AllowVnetOutBound",             "direction": "Outbound", "priority": 65000, "access": "Allow" },
      { "name": "AllowInternetOutBound",         "direction": "Outbound", "priority": 65001, "access": "Allow" },
      { "name": "DenyAllOutBound",               "direction": "Outbound", "priority": 65500, "access": "Deny"  }
    ],
    "id": "/subscriptions/<subscription-id>/resourceGroups/rg-idgov-lab/providers/Microsoft.Network/networkSecurityGroups/nsg-idgov-test",
    "location": "southafricanorth",
    "provisioningState": "Succeeded",
    "securityRules": [],
    ...
  }
}
```

**What this proves**
- Both resource groups deployed in South Africa North.
- Tags on a resource group do **not** flow down to its resources: the NSG has no `tags` property. This is the baseline for the tag inheritance policy in step 6.
- A new NSG denies all inbound traffic from the internet but **allows outbound internet** by default (AllowInternetOutBound, priority 65001).

> Troubleshooting note: the first attempt failed with `ReadOnlyDisabledSubscription` because the original subscription was disabled, which makes it read-only. Switching to an active subscription fixed it. A second attempt failed because Cloud Shell was in PowerShell, which can't parse `VAR=value`, heredocs or `source`; switching to Bash fixed it.
