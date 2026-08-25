targetScope = 'subscription'

param enableSoftDelete bool
param envConfig string
param region string
param storageAccountRGName string
param storageAccountName string
param appShortName string
param userGroupPrincipalID string
param infraResourceGroupName string = 'rg-nbsse-${envConfig}-infra'

var hubMap = {
  dev: 'dev'
  prod: 'prod'
}

var hub = hubMap[envConfig]
var privateEndpointRGName = 'rg-hub-${hub}-uks-hub-private-endpoints'
var privateDNSZoneRGName = 'rg-hub-${hub}-uks-private-dns-zones'
var userGroupName = 'screening_${appShortName}_${envConfig}'

resource storageAccountRG 'Microsoft.Resources/resourceGroups@2024-11-01' existing = {
  name: storageAccountRGName
}

resource privateEndpointResourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' existing = {
  name: privateEndpointRGName
}

resource privateDNSZoneRG 'Microsoft.Resources/resourceGroups@2024-11-01' existing = {
  name: privateDNSZoneRGName
}

module terraformStateStorageAccount 'terraformStorage.bicep' = {
  scope: storageAccountRG
  params: {
    storageLocation: region
    storageName: storageAccountName
    enableSoftDelete: enableSoftDelete
    userGroupPrincipalID: userGroupPrincipalID
    userGroupName: userGroupName
  }
}

module terraformStoragePrivateDnsZone 'dns.bicep' = {
  scope: privateDNSZoneRG
  params: {
    resourceServiceType: 'storage'
  }
}

module terraformStoragePrivateEndpoint 'privateEndpoint.bicep' = {
  scope: privateEndpointResourceGroup
  params: {
    hub: hub
    region: region
    name: storageAccountName
    resourceServiceType: 'storage'
    resourceID: terraformStateStorageAccount.outputs.storageAccountID
    privateDNSZoneID: terraformStoragePrivateDnsZone.outputs.privateDNSZoneID
  }
}

resource infraRG 'Microsoft.Resources/resourceGroups@2024-11-01' = {
  name: infraResourceGroupName
  location: region
}

output storageAccountId string = terraformStateStorageAccount.outputs.storageAccountID
output storagePrivateDNSZoneId string = terraformStoragePrivateDnsZone.outputs.privateDNSZoneID
output storagePrivateEndpointId string = terraformStoragePrivateEndpoint.outputs.privateEndpointID
output infraResourceGroupId string = infraRG.id
