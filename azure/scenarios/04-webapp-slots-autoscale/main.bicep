// Scenario 4: Zero-downtime web releases with deployment slots and autoscale.
// Compute (App Service). Resource group scope.

@description('Region for all resources. Defaults to the resource group region.')
param location string = resourceGroup().location

@description('Short prefix used in resource names.')
@minLength(3)
@maxLength(10)
param prefix string = 'shop'

@description('App Service plan SKU. S1 is the cheapest tier that supports deployment slots AND autoscale.')
@allowed([ 'S1', 'P0v3', 'P1v3' ])
param planSku string = 'S1'

var suffix = uniqueString(resourceGroup().id)
var appName = 'app-${prefix}-${suffix}'

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: 'asp-${prefix}'
  location: location
  kind: 'linux'
  sku: { name: planSku, capacity: 1 }
  properties: { reserved: true }      // reserved = Linux
}

resource app 'Microsoft.Web/sites@2023-12-01' = {
  name: appName
  location: location
  kind: 'app,linux'
  identity: { type: 'SystemAssigned' }   // ready for Key Vault / storage access without secrets
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'PHP|8.2'
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      alwaysOn: true
      healthCheckPath: '/'
      appSettings: [
        { name: 'ENVIRONMENT', value: 'production' }   // sticky: stays with this slot
        { name: 'APP_VERSION', value: 'v1' }           // swaps with the code
      ]
    }
  }
}

resource staging 'Microsoft.Web/sites/slots@2023-12-01' = {
  parent: app
  name: 'staging'
  location: location
  kind: 'app,linux'
  identity: { type: 'SystemAssigned' }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'PHP|8.2'
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      alwaysOn: true
      healthCheckPath: '/'
      appSettings: [
        { name: 'ENVIRONMENT', value: 'staging' }
        { name: 'APP_VERSION', value: 'v2' }
      ]
    }
  }
}

// Marks ENVIRONMENT as a "deployment slot setting" (sticky). It is set on the
// production site and applies to every slot.
resource stickySettings 'Microsoft.Web/sites/config@2023-12-01' = {
  parent: app
  name: 'slotConfigNames'
  properties: {
    appSettingNames: [ 'ENVIRONMENT' ]
  }
}

// Autoscale the PLAN (not the app): CPU > 70% for 10 min adds one instance,
// CPU < 30% for 10 min removes one. Max 3 caps the bill.
resource autoscale 'Microsoft.Insights/autoscalesettings@2022-10-01' = {
  name: 'autoscale-${plan.name}'
  location: location
  properties: {
    enabled: true
    targetResourceUri: plan.id
    profiles: [
      {
        name: 'cpu-based'
        capacity: { minimum: '1', maximum: '3', default: '1' }
        rules: [
          {
            metricTrigger: {
              metricName: 'CpuPercentage'
              metricResourceUri: plan.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT10M'
              timeAggregation: 'Average'
              operator: 'GreaterThan'
              threshold: 70
            }
            scaleAction: { direction: 'Increase', type: 'ChangeCount', value: '1', cooldown: 'PT5M' }
          }
          {
            metricTrigger: {
              metricName: 'CpuPercentage'
              metricResourceUri: plan.id
              timeGrain: 'PT1M'
              statistic: 'Average'
              timeWindow: 'PT10M'
              timeAggregation: 'Average'
              operator: 'LessThan'
              threshold: 30
            }
            scaleAction: { direction: 'Decrease', type: 'ChangeCount', value: '1', cooldown: 'PT5M' }
          }
        ]
      }
    ]
  }
}

output appName string = app.name
output productionUrl string = 'https://${app.properties.defaultHostName}'
output stagingUrl string = 'https://${staging.properties.defaultHostName}'
