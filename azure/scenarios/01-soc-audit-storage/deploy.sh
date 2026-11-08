#!/usr/bin/env bash
# Scenario 1: deploy. Run in Azure Cloud Shell (Bash) or any shell with az CLI logged in.
set -euo pipefail

# --- Variables (keep real values in a local env file, never commit them) ---
RG=${RG:-rg-scn01-socstorage}
LOC=${LOC:-southafricanorth}
PREFIX=${PREFIX:-soc}
READER_GROUP=${READER_GROUP:-grp-soc-analysts}     # Entra group allowed to read logs

# Your current public IP (Cloud Shell's outbound IP if you run it there)
MY_IP=${MY_IP:-$(curl -s https://api.ipify.org)}

# Create the reader group if it doesn't exist, and get its object ID
READER_ID=$(az ad group show --group "$READER_GROUP" --query id -o tsv 2>/dev/null || \
  az ad group create --display-name "$READER_GROUP" --mail-nickname "$READER_GROUP" --query id -o tsv)

# You, as the uploader for the test
ME_ID=$(az ad signed-in-user show --query id -o tsv)

az group create -n "$RG" -l "$LOC" -o table

# Preview first (what-if), then deploy
az deployment group what-if -g "$RG" -f main.bicep \
  -p prefix="$PREFIX" myPublicIp="$MY_IP" readerPrincipalId="$READER_ID" uploaderPrincipalId="$ME_ID"

az deployment group create -g "$RG" -n scn01 -f main.bicep \
  -p prefix="$PREFIX" myPublicIp="$MY_IP" readerPrincipalId="$READER_ID" uploaderPrincipalId="$ME_ID" \
  --query properties.outputs -o json
