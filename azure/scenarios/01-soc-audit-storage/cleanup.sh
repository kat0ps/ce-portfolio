#!/usr/bin/env bash
# Scenario 1: cleanup. Deletes everything the scenario created.
set -euo pipefail
RG=${RG:-rg-scn01-socstorage}
az group delete -n "$RG" --yes --no-wait
echo "Deleting $RG in the background. The Entra group grp-soc-analysts is kept; delete it with:"
echo "  az ad group delete --group grp-soc-analysts"
