// larkspur-ops-automation, M0: cost guardrail before anything billable exists.
// Subscription-scope budget filtered to this project's resource group.
//
// Same pattern as larkspur-azure-platform: code instead of the portal, because the portal's resource-group filter
// only lists groups that already have cost data, so a group that doesn't exist yet can't be selected.
targetScope = 'subscription'

@description('Budget name')
param budgetName string = 'budget-larkspur-ops'

@description('Monthly budget amount in the billing currency (USD)')
@minValue(1)
param amount int = 5

// Fixed dates, not utcNow(): what-if can't evaluate utcNow(), and next month the expression would try to move an
// existing budget's start date. endDate equals Azure's default (start + 10 years) so what-if reports NoChange.
@description('First day of the budget period (must be the first of a month)')
param startDate string = '2026-11-01T00:00:00Z'

@description('Budget end date (Azure\'s default when none is given: start + 10 years)')
param endDate string = '2036-11-01T00:00:00Z'

@description('Resource groups whose cost counts toward this budget')
param resourceGroupNames array = [
  'rg-lark-ops' // Automation account, runbooks, alerts (job logs go to log-lark in rg-lark-data, already budgeted)
]

@description('Email for budget alerts. Supplied from a gitignored *.local.bicepparam file; @secure() keeps it out of deployment history.')
@secure()
param alertEmail string

resource budget 'Microsoft.Consumption/budgets@2023-11-01' = {
  name: budgetName
  properties: {
    category: 'Cost'
    amount: amount
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: startDate
      endDate: endDate
    }
    filter: {
      dimensions: {
        name: 'ResourceGroupName'
        operator: 'In'
        values: resourceGroupNames
      }
    }
    notifications: {
      Actual_50: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 50
        thresholdType: 'Actual'
        contactEmails: [
          alertEmail
        ]
      }
      Actual_100: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 100
        thresholdType: 'Actual'
        contactEmails: [
          alertEmail
        ]
      }
      Forecasted_100: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 100
        thresholdType: 'Forecasted'
        contactEmails: [
          alertEmail
        ]
      }
    }
  }
}

output budgetName string = budget.name
output filteredResourceGroups array = resourceGroupNames
