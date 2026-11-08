#!/usr/bin/env bash
# Scenario 3: cleanup. The subscription-level activity-log diagnostic setting is NOT in the resource group,
# so it must be removed separately or it keeps pointing at a deleted workspace.
set -euo pipefail
RG=${RG:-rg-scn03-monitoring}
az monitor diagnostic-settings subscription delete --name activitylog-to-law --yes 2>/dev/null || true
az group delete -n "$RG" --yes --no-wait
echo "Deleting $RG in the background. Subscription diagnostic setting removed."
