using './main.bicep'
param location = 'eastus'
param tags = {
  project: 'larkspur-ops-automation'
  company: 'Larkspur Logistics (fictional)'
  costCenter: 'CC-LARK-01'
  environment: 'lab'
  owner: 'platform'
}
param workspaceResourceGroup = 'rg-lark-data'
param workspaceName = 'log-lark'