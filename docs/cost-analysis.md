# Cost Analysis

## Actual month-to-date findings

The Cost Management service-level breakdown returned:

| Service | Cost |
| --- | ---: |
| VPN Gateway | CAD 4.5325914075 |
| Virtual Network | CAD 0.0604895321 |
| Azure Arc | CAD 0.0000000000 |

Combined observed spend: **CAD 4.5930809396**.

The VPN Gateway represented approximately **98.7%** of the observed spend.

## Remediation

The VPN Gateway had already been deleted when the follow-up audit was performed.

A subscription-wide resource query confirmed no remaining virtual network gateway resources.

Additional checks returned no:

- Public IP addresses
- NAT Gateways
- Bastion hosts
- Azure Firewalls
- Application Gateways
- Storage Accounts
- Network Watcher flow logs
- Connection Monitors

This materially reduced the lab continuing network-cost exposure.

## Log Analytics and Sentinel validation

The Sentinel workspace was queried directly through the Log Analytics API.

Observed billable ingestion over the prior 30 days:

| Data type | Billable volume |
| --- | ---: |
| SecurityEvent | 0.000140208 GB |

Workspace settings observed during the review:

- SKU: PerGB2018
- Retention: 30 days
- Daily cap: 0.03 GB/day

At this volume, Log Analytics was not the primary driver of the observed Azure bill.

## Defender for Cloud

The normal workload-protection plans observed in the lab were set to Free, including Servers, Storage, App Services, Containers, Key Vault, APIs, and related workload plans.

Discovery and FoundationalCspm appeared as Standard platform entries during the pricing review.

## Key lesson

Resource inventory alone is not enough for cost troubleshooting.

The most useful sequence was:

1. Query actual subscription cost by service.
2. Identify the dominant cost category.
3. Confirm whether the associated resource still exists.
4. Check for dependent resources that can continue billing.
5. Validate telemetry ingestion separately.
6. Keep automated guardrails in place for future drift.
