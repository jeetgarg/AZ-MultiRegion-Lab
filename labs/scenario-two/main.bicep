metadata name = 'Scenario Two'
metadata description = 'This bicep codes deploys application infrastructure for scenario two, a web based paas application with a database backend.'
targetScope = 'subscription'

@description('The Azure region you wish to deploy to.')
param location string = 'australiaeast'

@secure()
param sqlpassword string

var rgName = 'rg-waf-az-lab-scenario-two'
var vnetName = 's2-vnet-${uniqueString(subscription().id)}'
var sqlServerName = 's2-sql-${uniqueString(subscription().id)}'
var appServiceSpec = [
  {
    name: 's2-api-${uniqueString(subscription().id)}'
    kind: 'api'
    farmName: 's2-apiasp-${uniqueString(subscription().id)}'
  }
  {
    name: 's2-web-${uniqueString(subscription().id)}'
    kind: 'app'
    farmName: 's2-webasp-${uniqueString(subscription().id)}'
  }
]
var vnetAddressPrefix = [
  '192.168.0.0/16'
]
var subnetSpec = [
  {
    name: 'appGatewaySubnet'
    addressPrefix: '192.168.3.0/24'
  }
  {
    addressPrefix: '192.168.1.0/25'
    name: 'webSubnet'
  }
  {
    addressPrefix: '192.168.0.0/24'
    name: 'dataSubnet'
  }
]
module serverFarm 'br/public:avm/res/web/serverfarm:0.1.1' =  [for farm in appServiceSpec:{
  name: 'webASPDeploy-${farm.farmName}'
  scope: resourceGroup
  params: {
    name: farm.farmName
    location: location
    sku: {
      capacity: 1
      family: 'S'
      name: 'S1'
      size: 'S1'
      tier: 'Standard'
    }
  }
}
]

module appServices 'br/public:avm/res/web/site:0.3.6' = [for (app, i) in appServiceSpec: {
  name: 'appDeploy-${app.name}'
  scope: resourceGroup
  params: {
    kind: app.kind
    location: location
    name: app.name
    serverFarmResourceId: serverFarm[i].outputs.resourceId
    privateEndpoints: [
      {
        privateDnsZoneResourceIds: [
          webPrivateDnsZone.outputs.resourceId
        ]
        subnetResourceId: virtualNetwork.outputs.subnetResourceIds[1]
        tags: {
          Environment: 'lab'
        }
      }
    ]
  }
}]



resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgName
  location: location
}

module virtualNetwork 'br/public:avm/res/network/virtual-network:0.1.6' = {
  name: 'vnetDeployment'
  scope: resourceGroup
  params: {
    name: vnetName
    addressPrefixes: vnetAddressPrefix
    subnets: [
      for subnet in subnetSpec: {
        name: subnet.name
        addressPrefix: subnet.addressPrefix
      }      
    ]
  }
}

module webPrivateDnsZone 'br/public:avm/res/network/private-dns-zone:0.3.0' = {
  name: 'apiPrivateDnsZoneDeployment'
  scope: resourceGroup
  params: {
    name: 'privatelink.azurewebsites.net'
    location: 'global'
  }
}
 
module sqlServer 'br/public:avm/res/sql/server:0.4.0' = {
  name: 'sqlServerDeployment'
  scope: resourceGroup
  params: {
    // Required parameters
    name: sqlServerName
    // Non-required parameters
    administratorLogin: 'sqladmin'
    administratorLoginPassword: sqlpassword
    databases: [
      {
        name: 'azlabdb'
        maxSizeBytes: 2147483648
        skuName: 'Standard'
        skuTier: 'Standard'
      }
      {
        name: 'appdb'
        maxSizeBytes: 2147483648
        skuName: 'Standard'
        skuTier: 'Standard'

      }
    ]
    location: location
  }
} 