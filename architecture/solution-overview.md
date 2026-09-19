# Solution Overview

## Objective

The objective was to keep a CloudGenius Azure lab close to a CAD 10 monthly ceiling without relying only on portal alerts.

The design combines monitoring and action:

- Azure Cost Management provides month-to-date actual spend.
- Azure Automation executes the control logic.
- A system-assigned managed identity removes the need for stored credentials.
- RBAC limits the automation identity to the subscriptions it must monitor and control.
- A recurring schedule runs the assessment every three hours.
- The runbook stops supported workloads when spend reaches the emergency threshold.

## Logical flow

Azure Automation Schedule (every 3 hours)
→ PowerShell 7.4 runbook
→ Managed Identity
→ Cost Management ActualCost query against Dev and Prod
→ Combined month-to-date cost
→ Compare with CAD 9 threshold
→ If below threshold: exit without changes
→ If threshold reached: stop/deallocate supported workloads and report residual-cost resources

## Cost-control boundary

The runbook can stop workloads that expose a supported stop or deallocate operation. It deliberately avoids destructive deletion.

Resources such as VPN Gateways, Azure Firewall, Bastion, managed disks, storage, Log Analytics, App Service Plans, and some PaaS services require separate lifecycle decisions because there is no universal Azure stop operation that guarantees billing stops.

## Why CAD 9 instead of CAD 10

The lab target was CAD 10 per month, but the automated action threshold was set to CAD 9 to create a small buffer for delayed cost ingestion and reporting.

This is still an operational guardrail, not a guaranteed billing hard cap.
