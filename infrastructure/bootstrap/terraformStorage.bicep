param storageLocation string
param storageName string
param enableSoftDelete bool
param userGroupPrincipalID string
param userGroupName string

// Create storage account without public access
resource storageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: storageName
  location: storageLocation
  sku: {
    name: 'Standard_RAGRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    encryption: {
      requireInfrastructureEncryption: true
    }
    minimumTlsVersion: 'TLS1_2'
    publicNetworkAccess: 'Disabled'
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
    }
  }
}

// Create the blob service
resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2024-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    containerDeleteRetentionPolicy: {
      days: enableSoftDelete ? 15 : null
      enabled: enableSoftDelete
    }
    deleteRetentionPolicy: {
      days: enableSoftDelete ? 15 : null
      enabled: enableSoftDelete
    }
    isVersioningEnabled: true
  }
}

// Create the blob container
resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2024-01-01' = {
  parent: blobService
  name: 'terraform-state'
  properties: {
    publicAccess: 'None'
    defaultEncryptionScope: '$account-encryption-key'
    denyEncryptionScopeOverride: false
  }
}

// Define role assignments array
// See: https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles
var roleAssignments = [
  {
    roleName: 'blobContributor'
    roleId: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
    description: 'Blob Contributor access to the Terraform state resource group'
  }
]

// Entra ID Group RBAC assignments using loop
resource groupRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for role in roleAssignments:{
  name: guid(subscription().subscriptionId, userGroupPrincipalID, role.roleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', role.roleId)
    principalId: userGroupPrincipalID
    principalType: 'Group'
    description: '${userGroupName} ${role.description}'
  }
}]

// Output the storage account ID so it can be used to create the private endpoint
output storageAccountID string = storageAccount.id
