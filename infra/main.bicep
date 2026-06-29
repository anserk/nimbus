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
  }
}

module acr 'acr.bicep' = {
  name: 'acr-deploy'
  params: {
    location: location
  }
}

module aca 'aca.bicep' = {
  name: 'aca-deploy'
  params: {
    location: location
    acrId: acr.outputs.acrId
    queueName: storage.outputs.queueName
    kvName: kv.outputs.name
  }
}
