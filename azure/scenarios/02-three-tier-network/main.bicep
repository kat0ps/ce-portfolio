// Scenario 2: Hub-spoke network for a three-tier app.
// Networking. Resource group scope.

@description('Region for all resources. Defaults to the resource group region.')
param location string = resourceGroup().location

@description('Private IP of the (future) firewall / network virtual appliance in the hub.')
param nvaPrivateIp string = '10.0.1.4'

@description('Deploy a small test VM in the app subnet for Network Watcher tests. Off by default to save cost.')
param deployTestVm bool = false

@description('SSH public key for the test VM (only used when deployTestVm is true).')
@secure()
param sshPublicKey string = ''

param adminUsername string = 'azureuser'

// ---------- Application security groups: rules target roles, not IPs ----------
resource asgWeb 'Microsoft.Network/applicationSecurityGroups@2023-09-01' = { name: 'asg-web', location: location }
resource asgApp 'Microsoft.Network/applicationSecurityGroups@2023-09-01' = { name: 'asg-app', location: location }
resource asgDb 'Microsoft.Network/applicationSecurityGroups@2023-09-01' = { name: 'asg-db', location: location }

// ---------- NSGs ----------
resource nsgWeb 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-web'
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-https-from-internet'
        properties: {
          priority: 100, direction: 'Inbound', access: 'Allow', protocol: 'Tcp'
          sourceAddressPrefix: 'Internet', sourcePortRange: '*'
          destinationApplicationSecurityGroups: [ { id: asgWeb.id } ]
          destinationPortRange: '443'
        }
      }
    ]
  }
}

resource nsgApp 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-app'
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-8080-from-web'
        properties: {
          priority: 100, direction: 'Inbound', access: 'Allow', protocol: 'Tcp'
          sourceApplicationSecurityGroups: [ { id: asgWeb.id } ], sourcePortRange: '*'
          destinationApplicationSecurityGroups: [ { id: asgApp.id } ]
          destinationPortRange: '8080'
        }
      }
      {
        // The default AllowVnetInBound rule (65000) would otherwise let ANY VNet host in,
        // including peered networks. This explicit deny closes that gap.
        name: 'deny-other-vnet-inbound'
        properties: {
          priority: 4000, direction: 'Inbound', access: 'Deny', protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork', sourcePortRange: '*'
          destinationAddressPrefix: '*', destinationPortRange: '*'
        }
      }
    ]
  }
}

resource nsgData 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: 'nsg-data'
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-sql-from-app'
        properties: {
          priority: 100, direction: 'Inbound', access: 'Allow', protocol: 'Tcp'
          sourceApplicationSecurityGroups: [ { id: asgApp.id } ], sourcePortRange: '*'
          destinationApplicationSecurityGroups: [ { id: asgDb.id } ]
          destinationPortRange: '1433'
        }
      }
      {
        name: 'deny-other-vnet-inbound'
        properties: {
          priority: 4000, direction: 'Inbound', access: 'Deny', protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork', sourcePortRange: '*'
          destinationAddressPrefix: '*', destinationPortRange: '*'
        }
      }
    ]
  }
}

// ---------- Route table: force internet-bound traffic through the hub appliance ----------
resource rtSpoke 'Microsoft.Network/routeTables@2023-09-01' = {
  name: 'rt-spoke-egress'
  location: location
  properties: {
    disableBgpRoutePropagation: true
    routes: [
      {
        name: 'default-via-nva'
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: nvaPrivateIp
        }
      }
    ]
  }
}

// ---------- Hub ----------
resource hub 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'vnet-hub'
  location: location
  properties: {
    addressSpace: { addressPrefixes: [ '10.0.0.0/16' ] }
    subnets: [
      { name: 'snet-shared', properties: { addressPrefix: '10.0.1.0/24' } }
      { name: 'GatewaySubnet', properties: { addressPrefix: '10.0.255.0/27' } }   // name must be exact; no NSG
    ]
  }
}

// ---------- Spoke (three tiers) ----------
resource spoke 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: 'vnet-spoke-app'
  location: location
  properties: {
    addressSpace: { addressPrefixes: [ '10.1.0.0/16' ] }
    subnets: [
      {
        name: 'snet-web'
        properties: { addressPrefix: '10.1.1.0/24', networkSecurityGroup: { id: nsgWeb.id } }
      }
      {
        name: 'snet-app'
        properties: { addressPrefix: '10.1.2.0/24', networkSecurityGroup: { id: nsgApp.id }, routeTable: { id: rtSpoke.id } }
      }
      {
        name: 'snet-data'
        properties: { addressPrefix: '10.1.3.0/24', networkSecurityGroup: { id: nsgData.id }, routeTable: { id: rtSpoke.id } }
      }
    ]
  }
}

// ---------- Peering (needed in BOTH directions) ----------
resource hubToSpoke 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  parent: hub
  name: 'hub-to-spoke-app'
  properties: {
    remoteVirtualNetwork: { id: spoke.id }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false      // set true once a VPN gateway exists in the hub
  }
}

resource spokeToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2023-09-01' = {
  parent: spoke
  name: 'spoke-app-to-hub'
  properties: {
    remoteVirtualNetwork: { id: hub.id }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true     // accept traffic the NVA forwards on behalf of others
    useRemoteGateways: false        // set true once the hub has a gateway
  }
}

// ---------- Private DNS: VMs register themselves; the hub can resolve names ----------
resource dnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'corp.internal'
  location: 'global'
}

resource dnsLinkSpoke 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: dnsZone
  name: 'link-spoke-app'
  location: 'global'
  properties: {
    virtualNetwork: { id: spoke.id }
    registrationEnabled: true       // VMs in the spoke get A records automatically
  }
}

resource dnsLinkHub 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: dnsZone
  name: 'link-hub'
  location: 'global'
  properties: {
    virtualNetwork: { id: hub.id }
    registrationEnabled: false      // resolution only
  }
}

// ---------- Optional test VM (app tier, no public IP) ----------
resource nic 'Microsoft.Network/networkInterfaces@2023-09-01' = if (deployTestVm) {
  name: 'nic-vm-app01'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: { id: spoke.properties.subnets[1].id }
          privateIPAllocationMethod: 'Dynamic'
          applicationSecurityGroups: [ { id: asgApp.id } ]
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2023-09-01' = if (deployTestVm) {
  name: 'vm-app01'
  location: location
  properties: {
    hardwareProfile: { vmSize: 'Standard_B1s' }
    osProfile: {
      computerName: 'vm-app01'
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: { publicKeys: [ { path: '/home/${adminUsername}/.ssh/authorized_keys', keyData: sshPublicKey } ] }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: { createOption: 'FromImage', managedDisk: { storageAccountType: 'Standard_LRS' }, deleteOption: 'Delete' }
    }
    networkProfile: { networkInterfaces: [ { id: nic.id, properties: { deleteOption: 'Delete' } } ] }
  }
}

output hubId string = hub.id
output spokeId string = spoke.id
output testVmDeployed bool = deployTestVm
