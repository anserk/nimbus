targetScope = 'resourceGroup'

param location string = resourceGroup().location

module storage 'storage.bicep' = {
  name: 'storage-deploy'
  params: {
    location: location
  }
}

module acr 'acr.bicep' = {
  name: 'acr-deploy'
  params: {
    location: location
  }
}

module wrk 'monitoring.bicep' = {
  name: 'wrk-deploy'
  params: {
    location: location
  }
}

output storageAccountName string = storage.outputs.storageAccountName
output acrLoginServer string = acr.outputs.acrLoginServer
output acrId string = acr.outputs.acrId
output outputContainerName string = storage.outputs.outputContainerName
output queueName string = storage.outputs.queueName
output workspaceName string = wrk.outputs.name
