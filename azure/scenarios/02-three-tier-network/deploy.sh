#!/usr/bin/env bash
# Scenario 2: deploy. Network only is free; the optional VM costs about US$0.01/hour (B1s).
set -euo pipefail

RG=${RG:-rg-scn02-network}
LOC=${LOC:-southafricanorth}
TEST_VM=${TEST_VM:-false}          # TEST_VM=true ./deploy.sh to add the Network Watcher test VM

az group create -n "$RG" -l "$LOC" -o table

PARAMS=(deployTestVm="$TEST_VM")
if [ "$TEST_VM" = "true" ]; then
  [ -f ~/.ssh/id_rsa.pub ] || ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" -q
  PARAMS+=(sshPublicKey="$(cat ~/.ssh/id_rsa.pub)")
fi

az deployment group what-if -g "$RG" -f main.bicep -p "${PARAMS[@]}"
az deployment group create -g "$RG" -n scn02 -f main.bicep -p "${PARAMS[@]}" -o table
