#!/usr/bin/env bash
# Scenario 4: cleanup. The S1 plan bills per hour while it exists, so delete it straight after testing.
set -euo pipefail
RG=${RG:-rg-scn04-webapp}
az group delete -n "$RG" --yes --no-wait
rm -f v1.zip v2.zip
echo "Deleting $RG in the background."
