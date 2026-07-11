param deploymentPrincipalObjectId string

targetScope = 'resourceGroup'

param location string = resourceGroup().location

module storage 'storage.bicep' = {
  name: 'storage-deploy'
  params: {
    location: location
  }
}

module kv 'kv.bicep' = {
  name: 'kv-deploy'
  params: {
    location: location
    deploymentPrincipalObjectId: deploymentPrincipalObjectId
  }
}

module acr 'acr.bicep' = {
  name: 'acr-deploy'
  params: {
    location: location
  }
}

output storageAccountName string = storage.outputs.storageAccountName
output kvName string = kv.outputs.name
output acrLoginServer string = acr.outputs.acrLoginServer
output acrId string = acr.outputs.acrId
output outputContainerName string = storage.outputs.outputContainerName
