# Implementation Notes

## Azure Automation

A dedicated Azure Automation account was created in Canada Central with a PowerShell 7.4 runtime environment.

The runbook was published as CloudGenius-Azure-Cost-KillSwitch.

The implementation uses the Automation account system-assigned managed identity rather than a stored client secret.

## RBAC

The automation identity was validated with two roles on both monitored subscriptions:

- Contributor
- Cost Management Reader

Contributor was required because the emergency path needs to stop or deallocate supported resources. Cost Management Reader provides subscription cost visibility.

## Cost query

The runbook queries Azure Cost Management using ActualCost, MonthToDate, and Monthly granularity.

Costs from Dev and Prod are combined before threshold evaluation, and the returned billing currency is validated before any action is taken.

## Throttling handling

During testing, the Cost Management API repeatedly returned HTTP 429 responses.

The runbook was updated with retry and backoff logic rather than failing on the first throttled request. If cost data cannot be trusted after retries, the runbook exits without executing shutdown actions.

## Dry-run validation

Before enabling live actions, a TestMode guard was added to the action wrapper.

In test mode, the runbook reports the action it would execute and returns without invoking the underlying stop operation.

The dry run confirmed managed identity authentication, successful subscription queries, combined-cost calculation, and safe behavior below the threshold.

## Scheduling

The first schedule was hourly. It was later changed to every three hours to reduce monthly Azure Automation runtime while preserving regular cost checks.

The schedule was linked to the runbook through an Azure Automation JobSchedule resource.

## Post-deployment audit

A separate read-only PowerShell audit was used to inventory potential cost-generating resources and compare them with actual Cost Management data.

This separated two questions:

1. What has already cost money this month?
2. What resources still exist that could continue costing money?
