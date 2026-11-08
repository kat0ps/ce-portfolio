// Scenario 1: SOC audit-log storage
// Storage + identity + monitoring. Resource group scope.

@description('Region for all resources. Defaults to the resource group region.')
param location string = resourceGroup().location

@description('Short prefix used in resource names (lowercase letters and numbers).')
@minLength(3)
@maxLength(8)
param prefix string = 'soc'

@description('Your public IP address, allowed through the storage firewall so you can test from your machine.')
param myPublicIp string

@description('Object ID of the Entra group that may READ audit logs (for example, SOC analysts).')
param readerPrincipalId string

@description('Object ID of the identity that uploads logs during the test (usually you).')
param uploaderPrincipalId string

@description('Days before blobs move to Cool, then Cold, and are finally deleted.')
param coolAfterDays int = 30
param coldAfterDays int = 90
param deleteAfterDays int = 730

var storageName = toLower('st${prefix}${uniqueString(resourceGroup().id)}')
var roleBlobDataReader = '2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
var roleBlobDataContributor = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'

// Network the log collectors live in. The subnet gets a service endpoint so the
// storage firewall can allow it by name instead of by IP.
resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'vnet-${prefix}-collectors'
  location: location
  properties: {
    addressSpace: { addressPrefixes: [ '10.40.0.0/16' ] }
    subnets: [
      {
        name: 'snet-collectors'
        properties: {
          addressPrefix: '10.40.1.0/24'
          serviceEndpoints: [ { service: 'Microsoft.Storage' } ]
        }
      }
    ]
  }
}

// Zone-redundant, Entra-only, private-by-default storage account.
resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: location
  sku: { name: 'Standard_ZRS' }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false          // forces Microsoft Entra ID (no account keys, no key-signed SAS)
    defaultToOAuthAuthentication: true
    networkAcls: {
      defaultAction: 'Deny'
      bypass: 'AzureServices'
      virtualNetworkRules: [
        { id: vnet.properties.subnets[0].id, action: 'Allow' }
      ]
      ipRules: [
        { value: myPublicIp, action: 'Allow' }
      ]
    }
  }
}

// Data protection: versioning, change feed, blob + container soft delete.
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storage
  name: 'default'
  properties: {
    isVersioningEnabled: true
    changeFeed: { enabled: true }
    deleteRetentionPolicy: { enabled: true, days: 30 }
    containerDeleteRetentionPolicy: { enabled: true, days: 30 }
  }
}

resource auditContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'audit-logs'
  properties: { publicAccess: 'None' }
}

// Lifecycle: Hot -> Cool -> Cold -> delete. Archive is NOT used because the
// Archive tier isn't supported on ZRS/GZRS accounts.
resource lifecycle 'Microsoft.Storage/storageAccounts/managementPolicies@2023-05-01' = {
  parent: storage
  name: 'default'
  properties: {
    policy: {
      rules: [
        {
          name: 'audit-logs-ageing'
          enabled: true
          type: 'Lifecycle'
          definition: {
            filters: {
              blobTypes: [ 'blockBlob' ]
              prefixMatch: [ 'audit-logs/' ]
            }
            actions: {
              baseBlob: {
                tierToCool: { daysAfterModificationGreaterThan: coolAfterDays }
                tierToCold: { daysAfterModificationGreaterThan: coldAfterDays }
                delete: { daysAfterModificationGreaterThan: deleteAfterDays }
              }
              version: {
                delete: { daysAfterCreationGreaterThan: 90 }
              }
            }
          }
        }
      ]
    }
  }
}

// Least-privilege data-plane access, scoped to the container only.
resource readerAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(auditContainer.id, readerPrincipalId, roleBlobDataReader)
  scope: auditContainer
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleBlobDataReader)
    principalId: readerPrincipalId
  }
}

resource uploaderAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(auditContainer.id, uploaderPrincipalId, roleBlobDataContributor)
  scope: auditContainer
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleBlobDataContributor)
    principalId: uploaderPrincipalId
  }
}

// Who read, wrote or deleted what: blob resource logs to Log Analytics.
resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'log-${prefix}-audit'
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

resource blobDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'blob-to-law'
  scope: blobService
  properties: {
    workspaceId: workspace.id
    logs: [
      { category: 'StorageRead', enabled: true }
      { category: 'StorageWrite', enabled: true }
      { category: 'StorageDelete', enabled: true }
    ]
    metrics: [
      { category: 'Transaction', enabled: true }
    ]
  }
}

output storageAccountName string = storage.name
output containerName string = auditContainer.name
output workspaceName string = workspace.name
