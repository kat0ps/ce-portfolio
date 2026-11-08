#!/usr/bin/env bash
# Scenario 3: verification. Fires real alerts by making safe, reversible changes.
set -uo pipefail
RG=${RG:-rg-scn03-monitoring}
LOC=${LOC:-southafricanorth}

echo "== 1. Alert rules and action group =="
az monitor activity-log alert list -g "$RG" --query "[].{name:name, enabled:enabled}" -o table
az monitor action-group show -g "$RG" -n ag-ops-oncall --query "{name:name, shortName:groupShortName, emails:length(emailReceivers)}" -o table

echo "== 2. Test the action group =="
echo "Portal: Monitor > Alerts > Action groups > ag-ops-oncall > Test > pick 'Service Health' > Test."
echo "Screenshot the test result and the email you receive."

echo "== 3. Fire 'NSG rule changed': create a test NSG, add a rule, then remove it =="
az network nsg create -g "$RG" -n nsg-alert-test -l "$LOC" -o none
az network nsg rule create -g "$RG" --nsg-name nsg-alert-test -n test-ssh-from-internet \
  --priority 300 --access Allow --protocol Tcp --destination-port-ranges 22 --source-address-prefixes Internet -o none
echo "Rule created. Expect an email within ~5 minutes from ala-nsg-rule-changed."

echo "== 4. Budget =="
az consumption budget list --resource-group "$RG" \
  --query "[].{name:name, amount:amount, grain:timeGrain, start:timePeriod.startDate}" -o table

echo "== 5. Activity log is landing in Log Analytics (allow 5-15 minutes) =="
WS=$(az deployment group show -g "$RG" -n scn03 --query properties.outputs.workspaceName.value -o tsv)
WS_ID=$(az monitor log-analytics workspace show -g "$RG" -n "$WS" --query customerId -o tsv)
az monitor log-analytics query -w "$WS_ID" --analytics-query "
AzureActivity
| where TimeGenerated > ago(1h)
| where OperationNameValue has 'securityRules/write' or OperationNameValue has 'networkSecurityGroups/write'
| project TimeGenerated, OperationNameValue, ActivityStatusValue, ResourceGroup
| order by TimeGenerated desc" -o table

echo
echo "Clean up the test NSG when you have your evidence:"
echo "  az network nsg delete -g $RG -n nsg-alert-test"
