# larkspur-ops-automation: plan

**Status:** plan approved 11-22-2026. This is the plan as written; results and deviations go in the README and
`docs/incidents/` as each milestone closes.

## Business problem

The Larkspur Logistics platform ([larkspur-azure-platform](https://github.com/ChefBoyRJeff/larkspur-azure-platform))
works and is documented, but its operations checks are manual. Its own incidents showed the gaps:

| Gap | Shown by |
|---|---|
| Nothing detects configuration drift between deploys | INC-008: a portal edit went unnoticed until customers failed |
| The free database's only warning is a floor at 10,000 vCore-seconds | INC-010: about 7 hours of warning before a month-long lockout |
| Nobody reviews who holds which role | M8: every break needed my Owner account |
| Cost is checked by hand | M9 cost report: a one-off query |
| Untagged and orphaned resources are found by accident | The lab series: leftover vaults, collections and budgets |

This project runs those checks on a schedule, under a managed identity with read-only access, and alerts when one
finds something or fails to run.

## Scope

- **Deployed:** an Azure Automation account (`aa-lark-ops`) in a new resource group `rg-lark-ops`, PowerShell 7.4
  runbooks, schedules, a diagnostic setting sending job logs to the existing `log-lark` workspace, two alerts using
  the existing `ag-lark-ops` action group, a $5 budget.
- **Read-only by design:** every runbook reports; none changes or deletes anything. Remediation stays a human
  decision through the normal path (pipeline or PR).
- **Out of scope:** auto-remediation, Hybrid Runbook Workers (no on-premises machines yet; a later home lab could add
  them), Logic Apps, Azure Functions.

## Architecture

| Component | Where | Notes |
|---|---|---|
| `aa-lark-ops` Automation account, Basic SKU | `rg-lark-ops`, East US | System-assigned managed identity; no Run As accounts, no stored credentials |
| Runtime environment | `aa-lark-ops` | PowerShell 7.4 (Az modules included by default) |
| Runbooks + schedules | `aa-lark-ops` | One runbook per check (below) |
| Diagnostic setting | on `aa-lark-ops` | Job logs and job streams to `log-lark` (`rg-lark-data`, 0.1 GB/day cap) |
| Alert: runbook failed | `rg-lark-ops` | Metric alert on Total Jobs, Status = Failed, filtered to my runbook names (an unfiltered rule also counts hidden system runbooks) |
| Alert: finding reported | `rg-lark-ops` | Log search alert every 15 minutes on `LARK-FINDING` lines in the job streams |
| Action group | existing `ag-lark-ops` | Email |

**Finding format.** Each runbook writes one line per finding to its output:
`LARK-FINDING check=<name> severity=<low|medium|high> resource=<name> detail=<text>`, plus a closing
`LARK-SUMMARY check=<name> findings=<n> checked=<n>` line. No IDs, emails or secrets go into the output.

## Runbooks

| Runbook | Schedule | Checks | Finds |
|---|---|---|---|
| `Invoke-LarkAccessReport` | Weekly | Role assignments at subscription and resource-group scope | Owner or User Access Administrator assignments; roles assigned directly to users instead of groups; assignments whose principal no longer exists (needs a directory read: decided in M2) |
| `Invoke-LarkDriftCheck` | Daily | Live Larkspur configuration vs expected values | The API's and jobs' `AZURE_CLIENT_ID` not matching their identities (INC-008); `minReplicas` not 1; a `keepwarm` job present (INC-010). Skips quietly when no session is deployed |
| `Invoke-LarkCostGuard` | Daily | Free SQL status and allowance; month-to-date cost | Database Online for more than 2 hours; free allowance falling faster than a set rate; month-to-date cost past 50% of a budget |
| `Invoke-LarkHygieneReport` | Weekly | Tags and leftovers across the subscription | Resources missing `costCenter`; unattached disks; unused public IPs; empty resource groups; budgets for deleted projects |

## Milestones and acceptance criteria

| Milestone | Done when |
|---|---|
| **M0** Prerequisites | Providers registered (m0-01); prices checked (Automation free to 500 min; metric alerts free to 10 series; log search alert $0.50/month at 15 min); budget `budget-larkspur-ops` deployed and verified; plan committed |
| **M1** Platform | Automation account built in the portal, then codified in Bicep with what-if NoChange (known noise documented); managed identity with Reader + Cost Management Reader at subscription scope (my approval: a subscription-scope role assignment); a hello-world runbook authenticates with the identity and lists resource groups; its job stream appears in `log-lark` |
| **M2** Access report | Runbook runs on schedule; findings match a manual `az role assignment list` comparison; the directory-read decision is made and documented |
| **M3** Drift check | Detects a deliberately changed value during a session; skips cleanly with no session; no false finding on a clean deploy |
| **M4** Cost guard | Reports correct values against the portal; triggers on a deliberately low test threshold |
| **M5** Hygiene report | Findings match a manual check; nothing modified |
| **M6** Engineering | Shared module for logging, finding output and error handling; Pester unit tests with mocked Azure calls (labeled as mocks); PSScriptAnalyzer and Pester in a required GitHub check; runbooks published from the repo by a script |
| **M7** Incidents | At least three, each with evidence and a report: the identity loses a role (authorization failure, failed-job alert fires); drift injected and detected (finding alert fires); a third chosen from what M1–M6 turn up |
| **M8** Deliverables | README, Mermaid diagram, runbook, cost report, interview guide, limitations; clean-run proof |
| **M9** (optional) Toolkit | 2–3 `it-infrastructure-toolkit` scripts hardened with M6's module and mocked Pester tests |

## Security

- **Identity:** the Automation account's system-assigned managed identity. No secrets, certificates or Run As
  accounts.
- **Least privilege:** Reader and Cost Management Reader at subscription scope. Reader covers role assignments,
  resource configuration and SQL status. No write permissions anywhere.
- **Directory read (M2):** finding deleted principals needs Microsoft Graph read access for the identity, a
  tenant-level permission. It's decided in M2 with its own approval; without it the report lists principal IDs and
  types only.
- **Output hygiene:** runbooks never print subscription IDs, object IDs, emails or secrets; the leak check applies to
  evidence files as in Larkspur.

## Cost

| Item | Price (retail, East US, checked 11-22-2026) | Expected |
|---|---|---|
| Automation job run time | First 500 min/month free, then $0.002/min | ~100–250 min/month: **$0** |
| Metric alert (failed jobs) | First 10 monitored time series free | **$0** |
| Log search alert (findings), every 15 min | $0.50/month | **$0.50/month** (approved 11-22-2026) |
| Log Analytics ingestion | Within `log-lark`'s free allowance and 0.1 GB/day cap | **~$0** |
| **Total** | | **About $0.50/month** |

Budget: `budget-larkspur-ops`, $5/month on `rg-lark-ops`. Teardown: delete `rg-lark-ops` and the identity's role
assignments; `log-lark` keeps the history for its 30-day retention.

## Conventions (from Larkspur)

Dates MM-DD-YYYY; times `hh:mm AM/PM EST`; evidence in `docs/evidence/`, sanitized; branch, PR and merge in the
browser; leak check before every commit; portal first for a new resource type, then Bicep with what-if.
