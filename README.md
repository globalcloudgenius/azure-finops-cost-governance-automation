# Azure FinOps Cost Governance Automation

A practical Azure FinOps and cost-governance implementation built in the CloudGenius lab to identify active cost drivers, enforce a low monthly spend target, and automatically stop supported workloads when spend approaches a defined threshold.

This repository documents work completed in a live Azure lab environment rather than a theoretical reference architecture.

## What I built

The solution combines Azure Cost Management, Azure Automation, managed identity, RBAC, PowerShell, REST APIs, Log Analytics, Microsoft Sentinel, and Defender for Cloud.

The control flow is:

1. Query month-to-date actual cost across Dev and Prod subscriptions.
2. Retry Cost Management queries when Azure returns HTTP 429 throttling.
3. Validate the billing currency.
4. Compare combined spend against a CAD 9 emergency threshold for a CAD 10 monthly target.
5. Stop or deallocate supported workloads when the threshold is reached.
6. Report residual-cost resources that cannot be universally stopped.
7. Run automatically every three hours through Azure Automation.

## Results from the lab

During validation, the automation successfully authenticated with a system-assigned managed identity and queried both subscriptions.

| Service | Month-to-date cost |
| --- | ---: |
| VPN Gateway | CAD 4.5326 |
| Virtual Network | CAD 0.0605 |
| Azure Arc | CAD 0.0000 |
| **Total observed** | **CAD 4.5931** |

The VPN Gateway accounted for roughly 98.7% of the observed Azure spend. It was subsequently removed from the lab.

Follow-up validation confirmed there were no remaining Azure VPN Gateways, Public IPs, NAT Gateways, Bastion hosts, Azure Firewalls, Application Gateways, Storage Accounts, Network Watcher flow logs, or Connection Monitors in the Dev subscription.

Log Analytics was validated directly. The Sentinel workspace had only about **0.000140208 GB** of billable SecurityEvent ingestion over the prior 30 days, with **30-day retention** and a **0.03 GB/day daily cap**. This showed that Log Analytics was not the primary cost driver in this case.

## Automation design

The Azure Automation account uses a system-assigned managed identity. In the lab, the identity was granted:

- Contributor on the monitored subscriptions for emergency workload stop/deallocation actions.
- Cost Management Reader for cost-query access.

The runbook is designed to stop supported services such as Azure VMs, VM Scale Sets, AKS clusters, Azure Container Instances, App Services, and Data Factory triggers. It also reports resources that may continue generating cost after compute is stopped.

The runbook does **not** automatically delete resources.

## Safety controls

This implementation was tested in dry-run mode before live scheduling. The dry run verified managed identity authentication, Dev and Prod cost queries, currency handling, combined-cost calculation, threshold evaluation, and safe behavior below the threshold.

The runbook was then switched to live mode and scheduled every three hours. The three-hour cadence was chosen to reduce Azure Automation runtime while still providing regular cost checks.

## Repository layout

- architecture/solution-overview.md
- docs/implementation.md
- docs/cost-analysis.md
- docs/security-design.md
- docs/validation-results.md
- scripts/Azure-Cost-Audit.ps1
- scripts/CloudGenius-Azure-Cost-KillSwitch.ps1

## Skills demonstrated

- Azure Cost Management APIs
- Azure Automation and PowerShell 7.4
- Managed identities
- Azure RBAC
- Azure REST APIs
- Retry/backoff handling for API throttling
- Microsoft Sentinel and Log Analytics cost analysis
- Defender for Cloud pricing review
- Azure resource inventory and cleanup
- FinOps guardrails
- Operational validation and safe rollout

## Important note

This repository is a sanitized portfolio version of the implementation. Tenant IDs, subscription IDs, object IDs, and other environment-specific identifiers are intentionally excluded.

A cost threshold is a guardrail, not a guaranteed billing hard stop. Azure cost data can lag, and some services continue to incur charges unless they are deleted, resized, or otherwise reconfigured.
