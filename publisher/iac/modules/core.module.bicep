param prefix string
param location string
param principalId string
param applianceResourceProviderObjectId string

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2022-02-01-preview' = {
  location: location
  name: '${prefix}acr'
  sku: {
    name: 'Premium'
  }
  properties: {
    adminUserEnabled: true
    anonymousPullEnabled: false
    dataEndpointEnabled: false
  }
}

resource acrPullScope 'Microsoft.ContainerRegistry/registries/scopeMaps@2022-02-01-preview' = {
  parent: containerRegistry
  name: '_repositories_pull'
  properties: {
    actions: [
      'repositories/*/content/read'
    ]
    description: 'Can pull any repository of the registry'
  }
}


resource storage 'Microsoft.Storage/storageAccounts@2022-05-01' = {
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

resource storageBlobs 'Microsoft.Storage/storageAccounts/blobServices@2022-05-01' = {
  parent: storage
  name: 'default'

  resource appDefinitionContainer 'containers' = {
    name: 'appdefinition'
    properties: {
      publicAccess: 'None'
    }
  }
}

resource serverFarm 'Microsoft.Web/serverfarms@2022-03-01' = {
  kind: 'elastic'
  location: location
  name: '${prefix}plan'
  properties: {
    reserved: true
  }
  sku: {
    capacity: 1
    family: 'EP'
    name: 'EP1'
    size: 'EP1'
    tier: 'ElasticPremium'
  }
}

resource cosmosDB 'Microsoft.DocumentDb/databaseAccounts@2022-08-15-preview' = {
  name: '${prefix}cosmosdb'
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        failoverPriority: 0
        locationName: location
      }
    ]
    backupPolicy: {
      type: 'Periodic'
      periodicModeProperties: {
        backupIntervalInMinutes: 240
        backupRetentionIntervalInHours: 8
        backupStorageRedundancy: 'Geo'
      }
    }
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
    enableFreeTier: false
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: '${prefix}keyvault'
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenant().tenantId
    enabledForTemplateDeployment: true
    enableRbacAuthorization: true
  }

  resource cosmosDBConnectionStringSecret 'secrets' = {
    name: 'CosmosDBConnectionString'
    properties: {
      value: cosmosDB.listConnectionStrings().connectionStrings[0].connectionString
    }
  }

  resource containerRegistryUrlSecret 'secrets' = {
    name: 'registry'
    properties: {
      value: containerRegistry.properties.loginServer
    }
  }
}

var keyVaultSecretsOfficerRole = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7')
resource keyvaultSelfSecretsOfficer 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, principalId, keyVaultSecretsOfficerRole)
  scope: keyVault
  properties: {
    principalId: principalId
    principalType: 'User'
    roleDefinitionId: keyVaultSecretsOfficerRole
  }
}

var contributorRole = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
resource keyvaultApplianceResourceProviderContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, applianceResourceProviderObjectId, contributorRole)
  scope: keyVault
  properties: {
    principalId: applianceResourceProviderObjectId
    principalType: 'ServicePrincipal'
    roleDefinitionId: contributorRole
  }
}

var storageBlobDataContributorRole = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe')
resource storageSelfBlobDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storage.id, principalId, storageBlobDataContributorRole)
  scope: storage
  properties: {
    principalId: principalId
    principalType: 'User'
    roleDefinitionId: storageBlobDataContributorRole
  }
}

