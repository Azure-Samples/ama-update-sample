param commandsFunctionPrincipalId string
param scriptIdentityPrincipalId string
param keyVaultName string
param aciPrincipalId string

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

// Function Identity - Key Vault Secrets User
resource keyvaultFunctionAppPermissions 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, 'keyvaultFunctionAppPermissions')
  scope: keyVault
  properties: {
    principalId: commandsFunctionPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/4633458b-17de-408a-b874-0445c86b69e6'
  }
}

// Function Identity - Resource Group Contributor
resource resourceGroupFunctionAppPermissions 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, 'resourceGroupFunctionAppPermissions')
  scope: resourceGroup()
  properties: {
    principalId: commandsFunctionPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
  }
}

// ACI Identity - Key Vault Secrets User
resource keyvaultAciPermissions 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, 'keyvaultAciPermissions')
  scope: keyVault
  properties: {
    principalId: aciPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/4633458b-17de-408a-b874-0445c86b69e6'
  }
}

// ACI Identity - Resource Group Contributor
resource resourceGroupACIPermissions 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, 'resourceGroupACIPermissions')
  scope: resourceGroup()
  properties: {
    principalId: aciPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
  }
}

// Script Identity - Resource Group Contributor
resource scriptIdentityContributorPermissions 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, 'scriptIdentityContributorPermissions')
  properties: {
    principalId: scriptIdentityPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
  }
}

// Script Identity - Key Vault Secrets User
resource keyVauktScriptIdentitySecretUserPermissions 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, 'keyVauktScriptIdentitySecretUserPermissions')
  scope: keyVault
  properties: {
    principalId: scriptIdentityPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: '${subscription().id}/providers/Microsoft.Authorization/roleDefinitions/4633458b-17de-408a-b874-0445c86b69e6'
  }
}
