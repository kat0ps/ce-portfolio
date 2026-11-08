#!/usr/bin/env bash
# Scenario 4: verification. Proves slot behaviour, swap with preview, rollback and autoscale config.
set -uo pipefail

RG=${RG:-rg-scn04-webapp}
APP=$(az deployment group show -g "$RG" -n scn04 --query properties.outputs.appName.value -o tsv)
PROD=https://$(az webapp show -g "$RG" -n "$APP" --query defaultHostName -o tsv)
STG=https://$(az webapp show -g "$RG" -n "$APP" --slot staging --query defaultHostName -o tsv)

show() { curl -s "$1" | grep -E "<h1>|ENVIRONMENT|APP_VERSION" | sed -e 's/<[^>]*>//g' -e 's/^ *//'; }

echo "== 1. Before swap =="
echo "-- production --"; show "$PROD"
echo "-- staging --";    show "$STG"

echo "== 2. Sticky setting is configured =="
az webapp config appsettings list -g "$RG" -n "$APP" --query "[].{name:name, sticky:slotSetting}" -o table

echo "== 3. Swap WITH PREVIEW (phase 1): production settings applied to staging, nothing live yet =="
az webapp deployment slot swap -g "$RG" -n "$APP" --slot staging --target-slot production --action preview
sleep 30
echo "-- staging now runs v2 code with PRODUCTION settings (warm-up check) --"; show "$STG"
echo "-- production unchanged --"; show "$PROD"

read -r -p "Looks good? Press Enter to complete the swap (Ctrl+C then run with --action reset to cancel)..."

echo "== 4. Complete the swap (phase 2) =="
az webapp deployment slot swap -g "$RG" -n "$APP" --slot staging --target-slot production --action swap
sleep 20
echo "-- production: release 2 code, ENVIRONMENT still 'production' (sticky), APP_VERSION v2 (swapped) --"; show "$PROD"
echo "-- staging: holds the previous release, ready for instant rollback --"; show "$STG"

echo "== 5. Autoscale rules on the plan =="
az monitor autoscale show -g "$RG" -n "autoscale-asp-${PREFIX:-shop}" \
  --query "{min:profiles[0].capacity.minimum, max:profiles[0].capacity.maximum, rules:profiles[0].rules[].{op:metricTrigger.operator, threshold:metricTrigger.threshold, action:scaleAction.direction}}" -o json

echo "== 6. Plan tier supports slots + autoscale =="
az appservice plan show -g "$RG" -n "asp-${PREFIX:-shop}" --query "{sku:sku.name, tier:sku.tier, workers:sku.capacity}" -o table

echo
echo "Rollback drill (optional): swap again to put release 1 back in production:"
echo "  az webapp deployment slot swap -g $RG -n $APP --slot staging --target-slot production"
