param location string = resourceGroup().location
param tenantId string = subscription().tenantId
param skuName string = 'standard'
param kvName string = 'kv-${uniqueString(resourceGroup().id)}'

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
    enablePurgeProtection: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
  }
}

output name string = kv.name
output resourceId string = kv.id
