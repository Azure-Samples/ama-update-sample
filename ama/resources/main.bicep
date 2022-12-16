param location string = resourceGroup().location

var prefix = 'app${uniqueString(subscription().id, resourceGroup().name)}'

var dockerRegistry = 'mcr.microsoft.com'
var dockerImageFullName = '${dockerRegistry}/azure-functions/dotnet:4-appservice-quickstart'


resource appStorage 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  kind: 'Storage'
  location: location
  name: '${prefix}storage'
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
  sku: {
    name: 'Standard_LRS'
  }
}

resource appStorageBlobs 'Microsoft.Storage/storageAccounts/blobServices@2022-05-01' = {
  parent: appStorage
  name: 'default'
}

resource appServerFarm 'Microsoft.Web/serverfarms@2022-03-01' = {
  kind: 'linux'
  location: location
  name: '${prefix}plan'
  properties: {
    reserved: true
  }
  sku: {
    name: 'B1'
    tier: 'Basic'
  }
}

resource appFunction 'Microsoft.Web/sites@2022-03-01' = {
  kind: 'functionapp,linux,container'
  location: location
  name: '${prefix}publicapp'
  properties: {
    httpsOnly: true
    serverFarmId: appServerFarm.id
    siteConfig: {
      acrUseManagedIdentityCreds: false
      http20Enabled: true
      linuxFxVersion: 'DOCKER|${dockerImageFullName}'
      appSettings: [
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: dockerRegistry
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${appStorage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${appStorage.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${appStorage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${appStorage.listKeys().keys[0].value}'
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
      ]
    }
  }
}

