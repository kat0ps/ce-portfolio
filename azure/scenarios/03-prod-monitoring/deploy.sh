#!/usr/bin/env bash
# Scenario 3: deploy. Alerts, action groups and budgets are free; Log Analytics charges per GB ingested.
set -euo pipefail

RG=${RG:-rg-scn03-monitoring}
LOC=${LOC:-southafricanorth}
: "${ALERT_EMAIL:?Set ALERT_EMAIL in your local env file first, e.g. export ALERT_EMAIL=you@example.com}"
BUDGET=${BUDGET:-20}

az group create -n "$RG" -l "$LOC" -o table

az deployment group what-if -g "$RG" -f main.bicep -p alertEmail="$ALERT_EMAIL" monthlyBudget="$BUDGET"
az deployment group create -g "$RG" -n scn03 -f main.bicep -p alertEmail="$ALERT_EMAIL" monthlyBudget="$BUDGET" -o table
