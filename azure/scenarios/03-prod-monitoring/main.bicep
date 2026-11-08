// Scenario 3: Production monitoring baseline (alerts, Service Health, budget, activity log retention).
// Monitor and maintain. Resource group scope, with one subscription-scope module.

@description('Region for the Log Analytics workspace. Defaults to the resource group region.')
param location string = resourceGroup().location

@description('Email address that receives alerts. Pass it at deploy time; never commit it.')
param alertEmail string

@description('Monthly budget for this resource group, in the billing currency.')
param monthlyBudget int = 20

@description('Budget start: must be the first day of a month. Defaults to the current month.')
param budgetStartDate string = utcNow('yyyy-MM-01')

@description('Send the subscription activity log to Log Analytics (keeps it beyond the 90-day default).')
param exportActivityLog bool = true

// ---------- Where the logs go ----------
resource workspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'log-ops-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 90
  }
}

// ---------- Who gets told ----------
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: 'ag-ops-oncall'
  location: 'global'
  properties: {
    groupShortName: 'opsoncall'          // max 12 characters; shows in SMS/email
    enabled: true
    emailReceivers: [
      { name: 'oncall-email', emailAddress: alertEmail, useCommonAlertSchema: true }
    ]
  }
}

// ---------- Activity log alerts (control-plane changes) ----------
resource alertVmDelete 'Microsoft.Insights/activityLogAlerts@2020-10-01' = {
  name: 'ala-vm-deleted'
  location: 'global'
  properties: {
    description: 'A virtual machine was deleted anywhere in the subscription.'
    enabled: true
    scopes: [ subscription().id ]
    condition: {
      allOf: [
        { field: 'category', equals: 'Administrative' }
        { field: 'operationName', equals: 'Microsoft.Compute/virtualMachines/delete' }
      ]
    }
    actions: { actionGroups: [ { actionGroupId: actionGroup.id } ] }
  }
}

resource alertNsgRule 'Microsoft.Insights/activityLogAlerts@2020-10-01' = {
  name: 'ala-nsg-rule-changed'
  location: 'global'
  properties: {
    description: 'An NSG rule was created or changed: possible exposure (e.g. RDP/SSH opened to the internet).'
    enabled: true
    scopes: [ subscription().id ]
    condition: {
      allOf: [
        { field: 'category', equals: 'Administrative' }
        { field: 'operationName', equals: 'Microsoft.Network/networkSecurityGroups/securityRules/write' }
        { field: 'status', equals: 'Succeeded' }
      ]
    }
    actions: { actionGroups: [ { actionGroupId: actionGroup.id } ] }
  }
}

resource alertAdvisor 'Microsoft.Insights/activityLogAlerts@2020-10-01' = {
  name: 'ala-advisor-new-recommendation'
  location: 'global'
  properties: {
    description: 'Azure Advisor raised a new recommendation (cost, security, reliability, performance).'
    enabled: true
    scopes: [ subscription().id ]
    condition: {
      allOf: [
        { field: 'category', equals: 'Recommendation' }
        { field: 'operationName', equals: 'Microsoft.Advisor/recommendations/available/action' }
      ]
    }
    actions: { actionGroups: [ { actionGroupId: actionGroup.id } ] }
  }
}

// ---------- Service Health (Azure's problems, not ours) ----------
resource alertServiceHealth 'Microsoft.Insights/activityLogAlerts@2020-10-01' = {
  name: 'ala-service-health'
  location: 'global'
  properties: {
    description: 'Azure service incidents, planned maintenance and security advisories affecting this subscription.'
    enabled: true
    scopes: [ subscription().id ]
    condition: {
      allOf: [
        { field: 'category', equals: 'ServiceHealth' }
        {
          anyOf: [
            { field: 'properties.incidentType', equals: 'Incident' }
            { field: 'properties.incidentType', equals: 'Maintenance' }
            { field: 'properties.incidentType', equals: 'Security' }
          ]
        }
      ]
    }
    actions: { actionGroups: [ { actionGroupId: actionGroup.id } ] }
  }
}

// ---------- Cost: budget on this resource group ----------
resource budget 'Microsoft.Consumption/budgets@2023-11-01' = {
  name: 'budget-${resourceGroup().name}'
  properties: {
    category: 'Cost'
    amount: monthlyBudget
    timeGrain: 'Monthly'
    timePeriod: { startDate: budgetStartDate }
    notifications: {
      actual80: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 80
        thresholdType: 'Actual'
        contactEmails: [ alertEmail ]
        contactGroups: [ actionGroup.id ]
      }
      forecast100: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 100
        thresholdType: 'Forecasted'
        contactEmails: [ alertEmail ]
        contactGroups: [ actionGroup.id ]
      }
    }
  }
}

// ---------- Subscription activity log -> Log Analytics ----------
module activityLogExport 'activity-log.bicep' = if (exportActivityLog) {
  name: 'activity-log-export'
  scope: subscription()
  params: { workspaceId: workspace.id }
}

output workspaceName string = workspace.name
output actionGroupName string = actionGroup.name
