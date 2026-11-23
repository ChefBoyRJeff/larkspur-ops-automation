// larkspur-ops-automation, M1: the platform for the ops runbooks.
// Subscription scope: the resource group, the module that builds the Automation account, and the managed
// identity's two read-only roles at subscription scope (the checks need to see every resource group).
targetScope = 'subscription'

@description('Region for the resource group and the Automation account')
param location string

@description('Tags applied to every resource this template creates')
param tags object

@description('Resource group that holds the Larkspur Log Analytics workspace')
param workspaceResourceGroup string

@description('Larkspur Log Analytics workspace that receives the job logs')
param workspaceName string

// Built-in role definition IDs (the same in every tenant).
var roleIds = {
  reader: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
  costManagementReader: '72fafb9e-0641-4937-9268-a91bfd8191a3'
}

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-lark-ops'
  location: location
  tags: tags
}

module automation 'modules/automation.bicep' = {
  name: 'lark-ops-automation'
  scope: rg
  params: {
    location: location
    tags: tags
    workspaceResourceGroup: workspaceResourceGroup
    workspaceName: workspaceName
  }
}

// guid() names: the same inputs always give the same name, so redeploying is a no-op (the CLI picks random names).
resource readerAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, 'aa-lark-ops', roleIds.reader)
  properties: {
    principalId: automation.outputs.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds.reader)
  }
}

resource costReaderAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, 'aa-lark-ops', roleIds.costManagementReader)
  properties: {
    principalId: automation.outputs.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleIds.costManagementReader)
  }
}

output automationAccountName string = automation.outputs.automationAccountName