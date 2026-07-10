param deploymentPrincipalObjectId string
param cities string
param deployJob bool = true

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

// See notein aca.bicep.
// module aca 'aca.bicep' = {
//   name: 'aca-deploy'
//   params: {
//     location: location
//     acrLoginServer: acr.outputs.acrLoginServer
//     acrId: acr.outputs.acrId
//     queueName: storage.outputs.queueName
//     kvName: kv.outputs.name
//   }
// }

module acajob 'aca-job.bicep' = if (deployJob) {
  name: 'aca-job-deploy'
  params: {
    location: location
    cities: cities
    acrLoginServer: acr.outputs.acrLoginServer
    acrId: acr.outputs.acrId
    kvName: kv.outputs.name
  }
}

output storageAccountName string = storage.outputs.storageAccountName
output kvName string = kv.outputs.name
