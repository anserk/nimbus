// infra/aca-job.bicep
param location string = resourceGroup().location
param acrLoginServer string
param cities string
param acrId string

resource weatherJob 'Microsoft.App/jobs@2023-05-01' = {
  name: 'weather-etl-job'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    environmentId: resourceId('Microsoft.App/managedEnvironments', 'env-learning')
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
    }
    template: {
      containers: [
        {
          name: 'weather-etl'
          image: '${acrLoginServer}/etl/weather:latest'
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
