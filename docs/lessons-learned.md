# Lessons Learned

## 1. Start with actual cost, not resource guesses

The resource inventory initially showed several Azure services that could potentially generate cost, but the Cost Management breakdown identified the real issue quickly: VPN Gateway represented roughly 98.7% of the observed month-to-date spend.

That changed the remediation priority immediately.

## 2. Deleted resources still appear in month-to-date cost

After the VPN Gateway was removed, the historical charge remained visible in Cost Management. This is expected because month-to-date cost represents usage already incurred.

The correct validation was to confirm that the gateway resource and its dependent public IP resources no longer existed.

## 3. A resource can be present without being the cost driver

The Sentinel and Log Analytics workspace looked like an obvious candidate because it collects security data, but the Logs API showed only 0.000140208 GB of billable SecurityEvent ingestion over 30 days.

Direct measurement prevented unnecessary removal of useful security monitoring.

## 4. Cost Management APIs can throttle aggressively

Manual and automated queries encountered HTTP 429 responses.

The runbook therefore needed retry and backoff handling. A single failed API request should not cause an emergency shutdown based on an unknown cost value.

## 5. Dry-run before live automation

The cost-control runbook was first executed with TestMode enabled.

The dry run proved authentication, RBAC, cost retrieval, currency handling, combined-cost logic, and threshold behavior before any stop operation was allowed.

## 6. Automation itself should be cost-aware

The original schedule ran hourly. It was deliberately changed to every three hours to reduce Azure Automation runtime while still providing regular cost checks.

FinOps controls should not become a new source of unnecessary cost.

## 7. A cost threshold is not a hard billing cap

Azure cost data can be delayed, and some services do not have a universal stop operation.

The CAD 9 threshold is therefore a practical safety margin below the CAD 10 target, not a mathematical guarantee that the bill can never exceed CAD 10.
