// infra/aca-job.bicep
param location string = resourceGroup().location
param acrLoginServer string
param cities string
param acrId string
param kvName string

resource env 'Microsoft.App/managedEnvironments@2026-01-01' = {
  name: 'env-learning'
  location: location
  properties: {}
}

resource weatherJob 'Microsoft.App/jobs@2023-05-01' = {
  name: 'weather-etl-job'
  location: location
  identity: {
    type: 'SystemAssigned'
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
          identity: 'system'
        }
      ]
      secrets: [
        {
          name: 'queue-connection-string'
          keyVaultUrl: 'https://${kvName}.vault.azure.net/secrets/queue-connection-string'
          identity: 'system'
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'weather-etl'
          // image: '${acrLoginServer}/etl/weather:latest'
          // this needs to exists, so use placeholder when building infra.
          // Helm, Flux / ArgoCD, Azure Deployment Environments deal with this
          // shoud do a follow up.
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

resource arcPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acrId, weatherJob.id, 'ArcPull')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '7f951dda-4ed3-4680-a7ca-43fe172d538d'
    )
    principalId: weatherJob.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

resource kvSecretUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(kvName, weatherJob.id, 'KvSecretsUser')
  scope: resourceGroup()
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '4633458b-17de-408a-b874-0445c86b69e6'
    )
    principalId: weatherJob.identity.principalId
    principalType: 'ServicePrincipal'
  }
}
