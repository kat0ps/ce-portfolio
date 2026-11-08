#!/usr/bin/env bash
# Scenario 4: deploy infrastructure, then push release 1 to production and release 2 to staging.
set -euo pipefail

RG=${RG:-rg-scn04-webapp}
LOC=${LOC:-southafricanorth}
PREFIX=${PREFIX:-shop}

az group create -n "$RG" -l "$LOC" -o table

az deployment group what-if -g "$RG" -f main.bicep -p prefix="$PREFIX"
az deployment group create -g "$RG" -n scn04 -f main.bicep -p prefix="$PREFIX" \
  --query properties.outputs -o json

APP=$(az deployment group show -g "$RG" -n scn04 --query properties.outputs.appName.value -o tsv)

# Zip deploy: release 1 -> production, release 2 -> staging
(cd site/v1 && zip -q -r ../../v1.zip .)
(cd site/v2 && zip -q -r ../../v2.zip .)
az webapp deploy -g "$RG" -n "$APP" --src-path v1.zip --type zip
az webapp deploy -g "$RG" -n "$APP" --slot staging --src-path v2.zip --type zip

echo "Production: https://$(az webapp show -g "$RG" -n "$APP" --query defaultHostName -o tsv)"
echo "Staging:    https://$(az webapp show -g "$RG" -n "$APP" --slot staging --query defaultHostName -o tsv)"
