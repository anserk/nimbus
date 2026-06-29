param arcName string = 'mylearningacr'
param location string = resourceGroup().location

@allowed(['Basic'])
param acrSku string = 'Basic'

resource acr 'Microsoft.ContainerRegistry/registries@2025-11-01' = {
  name: arcName
  location: location
  sku: {
    name: acrSku
  }
  properties: {
    adminUserEnabled: false
  }
}

output acrLoginServer string = acr.properties.loginServer
output acrId string = acr.id
