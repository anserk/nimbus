// infra/aca-job.bicep
param location string = resourceGroup().location
param acrLoginServer string
param cities string
param acrId string
param kvName string

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'id-weather-etl'
  location: location
}

resource acrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acrId, uami.id, 'AcrPull')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '7f951dda-4ed3-4680-a7ca-43fe172d538d'
    )
    principalId: uami.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource kvSecretUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(kvName, uami.id, 'KvSecretsUser')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '4633458b-17de-408a-b874-0445c86b69e6'
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

resource weatherJob 'Microsoft.App/jobs@2023-05-01' = {
  name: 'weather-etl-job'
  location: location
  dependsOn: [
    acrPull
    kvSecretUser
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
      triggerType: 'Schedule'
      replicaTimeout: 1800
      replicaRetryLimit: 2
      scheduleTriggerConfig: {
        cronExpression: '0 2 * * *'
        parallelism: 1
        replicaCompletionCount: 1
      }
      registries: [
        {
          server: acrLoginServer
          identity: uami.id
        }
      ]
      secrets: [
        {
          name: 'queue-connection-string'
          keyVaultUrl: 'https://${kvName}.vault.azure.net/secrets/queue-connection-string'
          identity: uami.id
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'weather-etl'
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
          env: [
            {
              name: 'CITIES'
              value: cities
            }
          ]
        }
      ]
    }
  }
}
