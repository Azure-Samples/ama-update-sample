targetScope = 'subscription'

param tag string
param resourceGroupName string
param principalId string
param applianceResourceProviderObjectId string
param location string = deployment().location

var unique = uniqueString(subscription().id, resourceGroupName)
var prefix = 'pr${unique}'
module rg 'modules/resourceGroup.module.bicep' = {
  name: resourceGroupName
  scope: subscription()
  params: {
    location: location
    name: resourceGroupName
  }
}

module core 'modules/core.module.bicep' = {
  name: 'core'
  scope: resourceGroup(resourceGroupName)
  dependsOn: [rg]
  params: {
    prefix: prefix
    location: location
    principalId: principalId
    applianceResourceProviderObjectId: applianceResourceProviderObjectId
  }
}

var functionNames = [
  'deployment'
  'events'
  'setcommandurl'
  'webhook'
]

module deploymentFunction 'modules/function.module.bicep' = [for functionName in functionNames: {
  name: '${functionName}Function'
  scope: resourceGroup(resourceGroupName)
  dependsOn: [core]
  params: {
    tag: tag
    functionName: functionName
    prefix: prefix
    location: location
  }  
}]

output prefix string = prefix
output tag string = tag
