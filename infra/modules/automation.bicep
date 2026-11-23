// larkspur-ops-automation, M1: Automation account, PowerShell 7.6 runtime environment, job logs to log-lark.
// Built first in the portal (M1 steps 1-3), then written here to match it; what-if proves the match.

@description('Region')
param location string

@description('Tags')
param tags object

@description('Resource group of the Log Analytics workspace')
param workspaceResourceGroup string

@description('Log Analytics workspace name')
param workspaceName string

// Runtime environments accept at most 3 tags (deploy error 11-22-2026: "RuntimeEnvironmentTags with value 5 cannot
// be greater than 3"), so they get the three that cost reporting and ownership need.
var runtimeTags = {
  costCenter: tags.costCenter
  project: tags.project
  owner: tags.owner
}

// Declared exactly as Azure stores a diagnostic setting (same lesson as Larkspur M5), so what-if shows no drift.
var noRetention = {
  days: 0
  enabled: false
}

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: workspaceName
  scope: resourceGroup(workspaceResourceGroup)
}

resource account 'Microsoft.Automation/automationAccounts@2024-10-23' = {
  name: 'aa-lark-ops'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    sku: {
      name: 'Basic'
    }
    publicNetworkAccess: true
    // Hardening: block non-Entra authentication (account keys, webhooks). The runbooks only use the managed identity.
    disableLocalAuth: true
    encryption: {
      keySource: 'Microsoft.Automation'
    }
  }
}

// PowerShell 7.6 LTS (supported to 11-14-2028). Package names are lowercase exactly as Azure stores them.
resource runtime 'Microsoft.Automation/automationAccounts/runtimeEnvironments@2024-10-23' = {
  parent: account
  name: 'rt-lark-ps76'
  location: location
  tags: runtimeTags
  properties: {
    description: 'Larkspur ops runbooks: PowerShell 7.6 + Az'
    runtime: {
      language: 'PowerShell'
      version: '7.6'
    }
    defaultPackages: {
      az: '15.1.0'
      'azure cli': '2.77.0'
    }
  }
}

// Job status and job streams (where the LARK-FINDING lines are) go to log-lark. The other categories and metrics
// stay off to keep ingestion low.
resource jobLogs 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'diag-to-log-lark'
  scope: account
  properties: {
    workspaceId: workspace.id
    logs: [
      {
        category: 'JobLogs'
        enabled: true
        retentionPolicy: noRetention
      }
      {
        category: 'JobStreams'
        enabled: true
        retentionPolicy: noRetention
      }
      {
        category: 'DscNodeStatus'
        enabled: false
        retentionPolicy: noRetention
      }
      {
        category: 'AuditEvent'
        enabled: false
        retentionPolicy: noRetention
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: false
        retentionPolicy: noRetention
      }
    ]
  }
}

output automationAccountName string = account.name
output principalId string = account.identity.principalId
