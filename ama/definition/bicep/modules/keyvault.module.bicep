param uniqueId string
param location string

@secure()
param applicationid string

@secure() 
param setcommandurlurl string

@secure()
param eventsurl string

@secure()
param registry string

@secure()
param registryUsername string

@secure()
param registryPassword string

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: '${uniqueId}keyvault'
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

  resource applicationIdSecret 'secrets' = {
    name: 'applicationid'
    properties: {
      value: applicationid
    }
  }

  resource setcommandurlurlSecret 'secrets' = {
    name: 'setcommandurlurl'
    properties: {
      value: setcommandurlurl
    }
  }

  resource eventsurlSecret 'secrets' = {
    name: 'eventsurl'
    properties: {
      value: eventsurl
    }
  }

  resource registrySecret 'secrets' = {
    name: 'registry'
    properties: {
      value: registry
    }
  }

  resource registryUsernameSecret 'secrets' = {
    name: 'registryUsername'
    properties: {
      value: registryUsername
    }
  }

  resource registryPasswordSecret 'secrets' = {
    name: 'registryPassword'
    properties: {
      value: registryPassword
    }
  }

  resource resourceGroupNameSecret 'secrets' = {
    name: 'resourceGroupName'
    properties: {
      value: resourceGroup().name
    }
  }
}

output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
