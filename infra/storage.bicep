@description('Storage Account type')
@allowed([
  'Standard_LRS'
])
param storageAccountType string = 'Standard_LRS'

@description('The storage account location.')
param location string = resourceGroup().location

@description('The name of the storage account')
param storageAccountName string = 'store${uniqueString(resourceGroup().id)}'

resource storageAccount 'Microsoft.Storage/storageAccounts@2026-04-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'StorageV2'
  properties: {}
}

resource queueService 'Microsoft.Storage/storageAccounts/queueServices@2026-04-01' = {
  parent: storageAccount
  name: 'default'
}

resource weatherQueue 'Microsoft.Storage/storageAccounts/queueServices/queues@2026-04-01' = {
  parent: queueService
  name: 'weather-queue'
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2026-04-01' = {
  parent: storageAccount
  name: 'default'
}

resource weatherOutput 'Microsoft.Storage/storageAccounts/blobServices/containers@2026-04-01' = {
  parent: blobService
  name: 'weather-output'
}

output storageAccountName string = storageAccountName
output storageAccountId string = storageAccount.id
output queueName string = weatherQueue.name
output outputContainerName string = weatherOutput.name
