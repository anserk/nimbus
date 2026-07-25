// This is not needed anymore. It was just a learning exercise.
// Not the problem is image needs to exists in acr for this to deploy
// but image is created in build-push that needs infra created ...
// chicken and egg.

param location string = resourceGroup().location
param acrId string
param weatherQueueName string
param kvName string
param acrLoginServer string
param image string

resource env 'Microsoft.App/managedEnvironments@2026-01-01' = {
  name: 'env-learning'
  location: location
  properties: {}
}

resource weatherApp 'Microsoft.App/containerApps@2026-01-01' = {
  name: 'weather-app'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    environmentId: env.id
    configuration: {
      ingress: {
        external: true
        targetPort: 80
      }
      registries: [
        {
          server: acrLoginServer
          identity: 'system'
        }
      ]
      secrets: [
        {
          name: 'storage-connection-string'
          keyVaultUrl: 'https://${kvName}.vault.azure.net/secrets/storage-connection-string'
          identity: 'system'
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'weather'
          image: image
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 30
        rules: [
          {
            name: 'queue-scaler'
            custom: {
              type: 'azure-queue'
              metadata: {
                queueName: weatherQueueName
                queueLength: '1'
              }
              auth: [
                {
                  secretRef: 'storage-connection-string'
                  triggerParameter: 'connection'
                }
              ]
            }
          }
        ]
      }
    }
  }
}

resource arcPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acrId, weatherApp.id, 'ArcPull')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '7f951dda-4ed3-4680-a7ca-43fe172d538d'
    )
    principalId: weatherApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource kvSecretUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(kvName, weatherApp.id, 'KvSecretsUser')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '4633458b-17de-408a-b874-0445c86b69e6'
    )
    principalId: weatherApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

output envId string = env.id
