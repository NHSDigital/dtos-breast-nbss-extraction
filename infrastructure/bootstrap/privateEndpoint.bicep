param hub string
param region string
param privateDnsZoneId string
param name string
param resourceId string
param resourceServiceType string

var hubResourceGroupName = 'rg-hub-${hub}-uks-hub-networking'
var hubVirtualNetworkName = 'VNET-${toUpper(hub)}-UKS-HUB'
var hubPrivateEndpointSubnetName = 'SN-${toUpper(hub)}-UKS-HUB-pep'

var groupIdsByServiceType = {
  storage: 'blob'
  keyVault: 'vault'
}

// Retrieve the existing hub resource group
resource hubResourceGroup 'Microsoft.Resources/resourceGroups@2024-11-01' existing = {
  name: hubResourceGroupName
  scope: subscription()
}

// Retrieve the existing hub virtual network
resource hubVirtualNetwork 'Microsoft.Network/virtualNetworks@2024-01-01' existing = {
  name: hubVirtualNetworkName
  scope: hubResourceGroup
}

// Retrieve the existing hub private endpoint subnet
resource hubPrivateEndpointSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' existing = {
  parent: hubVirtualNetwork
  name: hubPrivateEndpointSubnetName
}

// Create the private endpoint for the resource
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-01-01' = {
  name: '${name}-pep'
  location: region
  properties: {
    subnet: {
      id: hubPrivateEndpointSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: '${name}-pls-connection'
        properties: {
          privateLinkServiceId: resourceId
          groupIds: [
            groupIdsByServiceType[resourceServiceType]
          ]
        }
      }
    ]
  }
}

// Register the private endpoint in the private DNS zone
resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: privateEndpoint
  name: '${name}-dns-zone-group'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: '${name}-dns-zone-config'
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}

output privateEndpointId string = privateEndpoint.id
