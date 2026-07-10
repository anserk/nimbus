param deploymentPrincipalObjectId string
param location string = resourceGroup().location
param tenantId string = subscription().tenantId
param skuName string = 'standard'
param kvName string = 'kv-${uniqueString(resourceGroup().id)}-np'

resource kv 'Microsoft.KeyVault/vaults@2026-02-01' = {
  name: kvName
  location: location
  properties: {
    sku: {
      family: 'A'
      name: skuName
    }
    tenantId: tenantId
    enableRbacAuthorization: true
    // enablePurgeProtection: false
    // enableSoftDelete: false
    // softDeleteRetentionInDays: 7
  }
}

resource kvSecretOfficer 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(kv.id, deploymentPrincipalObjectId, 'KvSecretsOfficer')
  scope: kv
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'b86a8fe4-44ce-4948-aee5-eccb2c155cd7' // Key Vault Secrets Officer
    )
    principalId: deploymentPrincipalObjectId
    principalType: 'ServicePrincipal'
  }
}

output name string = kv.name
output resourceId string = kv.id
