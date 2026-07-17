// infra/aca-job.bicep
param location string = resourceGroup().location
param acrLoginServer string
param acrId string
param outputContainer string
param image string
param storageAccountId string
param storageAccountName string
param queueName string

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-weather-etl'
  location: location
}

resource acr 'Microsoft.ContainerRegistry/registries@2025-11-01' existing = {
  name: last(split(acrId, '/'))
}

resource storage 'Microsoft.Storage/storageAccounts@2026-04-01' existing = {
  name: storageAccountName
}

resource acrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acr.id, uami.id, 'AcrPull')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '7f951dda-4ed3-4680-a7ca-43fe172d538d'
    )
    principalId: uami.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource blobContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountId, uami.id, 'blobContributor')
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
    )
    principalId: uami.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource queueProcessor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountId, uami.id, 'queueProcessor')
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '8a0f0c08-91a1-4084-bc3d-661d67233fed'
    )
    principalId: uami.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource env 'Microsoft.App/managedEnvironments@2026-01-01' = {
  name: 'env-learning'
  location: location
  properties: {}
}

resource weatherJob 'Microsoft.App/jobs@2026-01-01' = {
  name: 'weather-etl-job'
  location: location
  dependsOn: [
    acrPull
    blobContributor
    queueProcessor
  ]
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uami.id}': {}
    }
  }
  properties: {
    environmentId: env.id
    configuration: {
      triggerType: 'Event'
      replicaTimeout: 1800
      replicaRetryLimit: 2
      eventTriggerConfig: {
        parallelism: 1
        replicaCompletionCount: 1
        scale: {
          maxExecutions: 100
          minExecutions: 0
          pollingInterval: 30
          rules: [
            {
              name: 'queue-scaler'
              type: 'azure-queue'
              identity: uami.id
              metadata: any({
                accountName: storageAccountName
                queueName:  queueName
                queueLength: '1'
              })
            }
          ]
        }
      }
      registries: [
        {
          server: acrLoginServer
          identity: uami.id
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'weather-etl'
          image: image
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'AZURE_STORAGE_ACCOUNT_NAME'
              value: storageAccountName
            }
            { name: 'OUTPUT_CONTAINER', value: outputContainer }
            { name: 'QUEUE_NAME', value: queueName}
            { name: 'AZURE_CLIENT_ID', value: uami.properties.clientId}
          ]
        }
      ]
    }
  }
}
