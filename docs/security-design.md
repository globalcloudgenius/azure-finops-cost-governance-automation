# Security Design

## Authentication

The runbook authenticates with an Azure Automation system-assigned managed identity.

No client secret, password, or certificate is embedded in the script.

## Authorization

The managed identity is scoped to the subscriptions it needs to monitor and control.

Roles used in the lab:

- Cost Management Reader for cost visibility.
- Contributor for emergency workload stop/deallocation actions.

Contributor does not grant permission to create new role assignments.

## Safe failure behavior

A cost-control system should not shut down infrastructure based on an unknown or incomplete cost value.

The runbook treats cost-query failure as a reason to abort the emergency action path.

HTTP 429 throttling is retried with backoff. If the cost query still cannot be trusted, the runbook exits without modifying workloads.

## Dry-run first

A test-mode guard was used before live rollout. This allowed the complete execution path to be validated without invoking the action scriptblocks.

## Public repository sanitization

The portfolio version excludes tenant IDs, subscription IDs, object IDs, credentials, tokens, and internal management addresses.

## Operational limitation

The runbook is intentionally non-destructive.

Some Azure resources can continue generating cost after compute is stopped. Examples include managed disks, VPN Gateway, Firewall, Bastion, Log Analytics, storage, and some PaaS services. Those resources must be reviewed separately rather than deleted automatically by a generic emergency runbook.
