targetScope = 'subscription'

param location string
param name string

resource resourceGroup 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: name
  location: location
}
