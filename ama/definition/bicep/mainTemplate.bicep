param location string = resourceGroup().location
param appName string
param managedAppResourceGroup string 

var uniqueId = 'p${uniqueString(subscription().id, resourceGroup().name, appName)}'
var managedAppId = resourceId(managedAppResourceGroup, 'Microsoft.Solutions/applications', appName)

var publisherPrefix = 'PUBLISHER_PREFIX'
var publisherResourceGroup='PUBLISHER_RESOURCE_GROUP'
var publisherSubscription='PUBLISHER_SUBSCRIPTION'
var dockerImageTag='DOCKER_IMAGE_TAG'
var containerRegistryName='${publisherPrefix}acr'
var publisherKeyVaultName='${publisherPrefix}keyvault'

var dockerImagePrefix='ama-update-sample'
var dockerImage='${dockerImagePrefix}-commands'
var dockerImageFullName='${containerRegistryName}.azurecr.io/${dockerImage}:${dockerImageTag}'


resource publisherKeyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: publisherKeyVaultName
  scope: resourceGroup(publisherSubscription, publisherResourceGroup)
}

module keyVaultModule 'modules/keyvault.module.bicep' = {
  name: 'keyvault'
  params: {
    location: location
    uniqueId: uniqueId
    applicationid: managedAppId
    setcommandurlurl: publisherKeyVault.getSecret('setcommandurlurl')
    eventsurl: publisherKeyVault.getSecret('eventsurl')
    registry: publisherKeyVault.getSecret('registry')
    registryUsername: publisherKeyVault.getSecret('registryUsername')
    registryPassword: publisherKeyVault.getSecret('registryPassword')
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultModule.outputs.keyVaultName
}

resource storage 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  kind: 'Storage'
  location: location
  name: '${uniqueId}storage'
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
}

resource serverFarm 'Microsoft.Web/serverfarms@2022-03-01' = {
  kind: 'linux'
  location: location
  name: '${uniqueId}plan'
  properties: {
    reserved: true
  }
  sku: {
    name: 'B1'
    tier: 'Basic'
  }
}

resource commandsFunction 'Microsoft.Web/sites@2022-03-01' = {
  kind: 'functionapp,linux,container'
  location: location
  name: '${uniqueId}commands'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    httpsOnly: true
    serverFarmId: serverFarm.id
    siteConfig: {
      acrUseManagedIdentityCreds: false
      http20Enabled: true
      linuxFxVersion: 'DOCKER|${dockerImageFullName}'
      appSettings: [
        {
          name: 'DOCKER_REGISTRY_SERVER_URL'
          value: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=registry)'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_USERNAME'
          value: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=registryUsername)'
        }
        {
          name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
          value: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=registryPassword)'
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
          value: '${uniqueId}deployment'
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
          name: 'AzureKeyVaultUrl'
          value: keyVaultModule.outputs.keyVaultUri
        }
      ]
    }
  }
}

module roleAssignments 'modules/roleAssignments.module.bicep' = {
  name: 'roleAssignments'
  params: {
    aciPrincipalId: containerInstance.identity.principalId
    commandsFunctionPrincipalId: commandsFunction.identity.principalId
    scriptIdentityPrincipalId: scriptIdentity.properties.principalId
    keyVaultName: keyVault.name
  }
}

resource containerInstance 'Microsoft.ContainerInstance/containerGroups@2022-09-01' = {
  name: 'aci'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    osType: 'Linux'
    restartPolicy: 'Never'
    containers: [
      {
        name: 'container'
        properties: {
          image: 'mcr.microsoft.com/mcr/hello-world'
          resources: {
            requests: {
              memoryInGB: '1.5'
              cpu: 1
            }
          }
        }
      }
    ]
  }
}

resource scriptIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: '${uniqueId}scriptIdentity'
  location: location
}

resource sendCommandsUrlScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  dependsOn: [
    roleAssignments
  ]
  name: '${uniqueId}sendCommandsUrl'
  kind: 'AzureCLI'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${scriptIdentity.id}': {}
    }
  }
  properties: {
    storageAccountSettings: {
      storageAccountName: storage.name
      storageAccountKey: storage.listKeys().keys[0].value
    }
    forceUpdateTag: '1'
    retentionInterval: 'P1D'
    azCliVersion: '2.41.0'
    arguments: '${uniqueId} ${resourceGroup().name} ${managedAppId} ${commandsFunction.name}'
    scriptContent: '''
      set -e

      uniqueId=$1
      resourceGroupName=$2
      managedAppId=$3
      functionName=$4

      attempts=20
      sleepTime=30
      set +e
      while [ $attempts -gt 0 ]; do
          functionKey=$(az functionapp keys list --resource-group $resourceGroupName --name $functionName --query "functionKeys.default" --output tsv)
          if [ -z "$functionKey" ]; then
              echo "Function key not found, retrying in ${sleepTime}s..."
              sleep $sleepTime
              attempts=$((attempts-1))
          else
              echo "Function key found"
              break
          fi
      done

      if [ -z "$functionKey" ]; then
          echo "Function key not found"
          exit 1
      fi

      functionUrl="https://${functionName}.azurewebsites.net/api/commands?code=${functionKey}"

      set -e
      
      # retrieve setcommandurlurl from keyvault
      keyVaultName=${uniqueId}keyvault
      setCommandUrlUrl=$(az keyvault secret show --vault-name $keyVaultName --name setcommandurlurl --query value -o tsv)

      # post function url to setcommandurlurl
      curl -v -X POST -H "Content-Type: application/json" -d "{\"applicationId\": \"$managedAppId\", \"commandUrl\": \"$functionUrl\"}" $setCommandUrlUrl

    '''
  }
}
