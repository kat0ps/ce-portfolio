#!/usr/bin/env bash
# Scenario 1: verification. Each step proves one requirement. Screenshot or copy the output into evidence/.
set -uo pipefail

RG=${RG:-rg-scn01-socstorage}
SA=$(az deployment group show -g "$RG" -n scn01 --query properties.outputs.storageAccountName.value -o tsv)
C=audit-logs
echo "Storage account: $SA"

echo "== 1. Security settings (no shared key, no public blob access, TLS 1.2, ZRS) =="
az storage account show -n "$SA" -g "$RG" \
  --query "{sku:sku.name, sharedKey:allowSharedKeyAccess, publicBlob:allowBlobPublicAccess, tls:minimumTlsVersion, defaultAction:networkRuleSet.defaultAction}" -o table

echo "== 2. Data protection (versioning, change feed, soft delete) =="
az storage account blob-service-properties show --account-name "$SA" -g "$RG" \
  --query "{versioning:isVersioningEnabled, changeFeed:changeFeed.enabled, blobSoftDelete:deleteRetentionPolicy.days, containerSoftDelete:containerDeleteRetentionPolicy.days}" -o table

echo "== 3. Lifecycle policy =="
az storage account management-policy show --account-name "$SA" -g "$RG" --query "policy.rules[].{name:name, prefix:definition.filters.prefixMatch[0]}" -o table

# RBAC role assignments can take a few minutes to apply after deployment.
echo "== 4. Upload with Entra ID (works) =="
echo "event=login user=alice result=failure $(date -u +%FT%TZ)" > sample-audit.log
az storage blob upload --account-name "$SA" -c "$C" -n "2026/11/sample-audit.log" -f sample-audit.log --auth-mode login --overwrite

echo "== 5. Overwrite creates a new version =="
echo "event=login user=alice result=success $(date -u +%FT%TZ)" > sample-audit.log
az storage blob upload --account-name "$SA" -c "$C" -n "2026/11/sample-audit.log" -f sample-audit.log --auth-mode login --overwrite
az storage blob list --account-name "$SA" -c "$C" --include v --auth-mode login \
  --query "[].{name:name, versionId:versionId, current:isCurrentVersion}" -o table

echo "== 6. Delete, then recover with soft delete =="
az storage blob delete --account-name "$SA" -c "$C" -n "2026/11/sample-audit.log" --auth-mode login
az storage blob undelete --account-name "$SA" -c "$C" -n "2026/11/sample-audit.log" --auth-mode login
az storage blob exists --account-name "$SA" -c "$C" -n "2026/11/sample-audit.log" --auth-mode login -o table

echo "== 7. NEGATIVE TEST: account key access is refused =="
az storage account keys list -n "$SA" -g "$RG" -o none 2>/dev/null && \
  az storage blob list --account-name "$SA" -c "$C" --auth-mode key -o table \
  || echo "Expected: key-based access is not permitted (allowSharedKeyAccess=false)."

echo "== 8. Resource logs reached Log Analytics (allow 5-15 minutes) =="
WS_ID=$(az monitor log-analytics workspace show -g "$RG" -n log-soc-audit --query customerId -o tsv 2>/dev/null)
[ -n "$WS_ID" ] && az monitor log-analytics query -w "$WS_ID" \
  --analytics-query "StorageBlobLogs | where TimeGenerated > ago(1h) | project TimeGenerated, OperationName, StatusText, CallerIpAddress, AuthenticationType | order by TimeGenerated desc | take 10" -o table
