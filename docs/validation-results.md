# Validation Results

## Automation account and runtime

The Automation account provisioned successfully in Canada Central.

The custom runtime environment was configured for PowerShell 7.4 and the runbook reached:

- State: Published
- Provisioning state: Succeeded

## Managed identity

The system-assigned managed identity was confirmed and its RBAC assignments were validated on both monitored subscriptions.

## Dry-run job

A manual Azure Automation job was executed before live scheduling.

Observed results:

- Managed identity authentication: SUCCESS
- Dev month-to-date cost: CAD 4.5931
- Prod month-to-date cost: CAD 0.0000
- Combined month-to-date cost: CAD 4.59308093958334
- Emergency threshold: CAD 9
- Result: STATUS: SAFE
- Workloads modified: None

The job completed successfully.

## Schedule validation

The original hourly schedule was replaced with a three-hour schedule to reduce Automation runtime consumption.

Final schedule characteristics:

- Frequency: Hour
- Interval: 3
- Enabled: True
- Time zone: UTC
- Linked runbook: CloudGenius-Azure-Cost-KillSwitch

The JobSchedule relationship was validated through the Azure Automation REST API.

## Cost-driver validation

Cost Management showed that the VPN Gateway was the dominant cost source.

After deletion, follow-up inventory confirmed no remaining VPN Gateway resource and no leftover public IP or other major paid network appliance in the Dev subscription.

## Log Analytics validation

The Logs API returned one billable data type during the 30-day review:

SecurityEvent = 0.000140208 GB

This was small enough to rule out Log Analytics as the main source of the observed CAD 4.59 spend.
