#!/usr/bin/env bash
# Scenario 2: cleanup.
set -euo pipefail
RG=${RG:-rg-scn02-network}
az group delete -n "$RG" --yes --no-wait
echo "Deleting $RG in the background."
