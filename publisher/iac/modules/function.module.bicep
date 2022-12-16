
param functionName string
param prefix string
param location string
param tag string

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2022-02-01-preview' existing = {
  name: '${prefix}acr'
}

resource storage 'Microsoft.Storage/storageAccounts@2022-05-01' existing = {
  name: '${prefix}storage'
}

resource serverFarm 'Microsoft.Web/serverfarms@2022-03-01' existing = {
  name: '${prefix}plan'
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: '${prefix}keyvault'
}

var dockerImageName = '${containerRegistry.name}.azurecr.io/ama-update-sample-${functionName}:${tag}'

resource site 'Microsoft.Web/sites@2022-03-01' = {
  kind: 'functionapp,linux,container'
  location: location
  name: '${prefix}${functionName}'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    httpsOnly: true
    serverFarmId: serverFarm.id
    siteConfig: {
      acrUseManagedIdentityCreds: false
      http20Enabled: true
      linuxFxVersion: 'DOCKER|${dockerImageName}'
      appSettings: [
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: 'https://${containerRegistry.name}.azurecr.io'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_USERNAME'
          value: containerRegistry.listCredentials().username
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
          value: containerRegistry.listCredentials().passwords[0].value
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storage.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storage.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: '${prefix}deployment'
        }
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet-isolated'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'CosmosDBConnectionString'
          value: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=CosmosDBConnectionString)'
        }
      ]
    }
  }
}

// secret user role
var keyVaultSecretsUserRole = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')

resource keyvaultFunctionAppPermissions 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, site.id, keyVaultSecretsUserRole)
  scope: keyVault
  properties: {
    principalId: site.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: keyVaultSecretsUserRole
  }
}
