# Elaro Operations Guide

**Version**: 1.0
**Last Updated**: 2026-02-02
**Owner**: Solentra Operations Team

---

## Overview

This guide provides comprehensive operational procedures for monitoring, maintaining, and troubleshooting the Elaro compliance platform in production.

---

## Table of Contents

1. [Governor Limit Monitoring](#governor-limit-monitoring)
2. [Compliance Gap Management](#compliance-gap-management)
3. [Scheduled Jobs](#scheduled-jobs)
4. [Dashboard Setup](#dashboard-setup)
5. [Alert Configuration](#alert-configuration)
6. [Audit Trail Management](#audit-trail-management)
7. [Performance Monitoring](#performance-monitoring)
8. [Troubleshooting](#troubleshooting)
9. [Maintenance Procedures](#maintenance-procedures)

---

## Governor Limit Monitoring

### Overview

Salesforce enforces governor limits to ensure multi-tenant platform stability. Elaro monitors these limits in real-time and sends alerts when thresholds are exceeded.

### Setup Instructions

#### 1. Enable System Monitor Dashboard

```bash
# Navigate to Setup → Apps → App Manager → Elaro
# Add "System Monitor Dashboard" to the app navigation
```

**Steps in UI**:
1. Setup → Apps → App Manager
2. Find "Elaro" app → Click "Edit"
3. Navigation Items → Add "System Monitor Dashboard"
4. Save

#### 2. Configure Alert Thresholds

**Location**: Setup → Custom Metadata Types → Governor Limit Threshold

**Recommended Thresholds**:

| Limit Type | Salesforce Max | Alert Threshold | Critical Threshold |
|------------|----------------|-----------------|-------------------|
| SOQL Queries | 100 | 80 (80%) | 90 (90%) |
| DML Statements | 150 | 120 (80%) | 135 (90%) |
| CPU Time (ms) | 10,000 | 7,500 (75%) | 9,000 (90%) |
| Heap Size (MB) | 6 | 4.2 (70%) | 5.4 (90%) |
| Callouts | 100 | 80 (80%) | 90 (90%) |
| SOSL Queries | 20 | 16 (80%) | 18 (90%) |

**Configuration Steps**:
1. Setup → Custom Metadata Types → Governor Limit Threshold → Manage Records
2. Click "New" for each limit type
3. Set threshold percentages
4. Enable email alerts
5. Save

#### 3. Set Up Alert Channels

**Email Alerts**:
```
Recipients: ops-team@solentra.com, engineering@solentra.com
Subject: [ELARO] Governor Limit Alert - {LimitType} at {Percentage}%
Severity: HIGH
```

**Slack Integration** (Optional):
```
Channel: #elaro-alerts
Webhook URL: [Configure in Elaro AI Settings]
Alert Format: Governor limit {LimitType} exceeded threshold ({Current}/{Max})
```

**Chatter Alerts**:
```
Group: @elaro-ops
Mention: When severity = CRITICAL
Post Type: Question (requires acknowledgment)
```

### Monitoring Queries

#### Current Governor Limit Usage

```sql
SELECT Id, LimitType__c, CurrentValue__c, MaxValue__c,
       PercentageUsed__c, Timestamp__c
FROM Governor_Limit_Snapshot__c
WHERE Timestamp__c = LAST_N_HOURS:1
ORDER BY PercentageUsed__c DESC
```

#### Governor Limit Violations (Last 24 Hours)

```sql
SELECT Id, LimitType__c, PercentageUsed__c, Context__c, Timestamp__c
FROM Governor_Limit_Snapshot__c
WHERE PercentageUsed__c > 80
  AND Timestamp__c = LAST_N_DAYS:1
ORDER BY Timestamp__c DESC
```

#### Top Offending Classes

```sql
SELECT Id, ClassName__c, MethodName__c, LimitType__c,
       PercentageUsed__c, COUNT(Id)
FROM Governor_Limit_Snapshot__c
WHERE PercentageUsed__c > 80
  AND CreatedDate = LAST_N_DAYS:7
GROUP BY ClassName__c, MethodName__c, LimitType__c
ORDER BY COUNT(Id) DESC
```

### Troubleshooting Governor Limits

#### SOQL Query Limit Exceeded

**Symptoms**:
- Users see error: "Too many SOQL queries: 101"
- Dashboard fails to load
- Batch jobs fail mid-execution

**Investigation**:
```sql
SELECT Id, ApexClass, DmlInfo, SoqlInfo, DurationMilliseconds
FROM ApexLog
WHERE Request = 'API' AND Status = 'Failure'
  AND DurationMilliseconds > 5000
  AND CreatedDate = TODAY
ORDER BY CreatedDate DESC
LIMIT 50
```

**Resolution**:
1. Identify offending class from logs
2. Review code for SOQL in loops
3. Implement bulkification
4. Cache repeated queries
5. Use aggregate queries where possible

#### CPU Time Limit Exceeded

**Symptoms**:
- Error: "Apex CPU time limit exceeded"
- Long-running operations timeout
- Performance degradation

**Investigation**:
```sql
SELECT Id, ApexClass, CpuTime, DurationMilliseconds
FROM ApexLog
WHERE CpuTime > 7500
  AND CreatedDate = LAST_N_DAYS:1
ORDER BY CpuTime DESC
```

**Resolution**:
1. Review CPU-intensive operations
2. Optimize loops and calculations
3. Move complex logic to @future or Queueable
4. Consider Platform Events for async processing
5. Break large operations into smaller batches

#### Heap Size Limit Exceeded

**Symptoms**:
- Error: "Apex heap size too large"
- Large data processing fails
- Dashboard with many records fails

**Investigation**:
```sql
SELECT Id, ApexClass, HeapSize, DurationMilliseconds
FROM ApexLog
WHERE HeapSize > 4000000
  AND CreatedDate = TODAY
ORDER BY HeapSize DESC
```

**Resolution**:
1. Reduce collection sizes
2. Process data in batches
3. Clear collections after use
4. Use streaming SOQL for large datasets
5. Avoid storing entire result sets in memory

---

## Compliance Gap Management

### Gap Lifecycle

```
Created → Identified → Assigned → In Progress → Resolved → Closed
```

### Alert Rules

| Severity | Notification | SLA | Escalation |
|----------|-------------|-----|------------|
| CRITICAL | Immediate Slack + Email | 4 hours | Level 2 if >50% SLA |
| HIGH | Email within 1 hour | 24 hours | Level 2 if >75% SLA |
| MEDIUM | Daily digest | 1 week | Level 2 if overdue |
| LOW | Weekly digest | 1 month | None |

### Notification Configuration

**Setup Location**: Setup → Process Builder → Compliance Gap Notification

**Alert Templates**:

**CRITICAL Alert**:
```
Subject: 🚨 CRITICAL Compliance Gap: {GapName}
Body:
A critical compliance gap has been identified:

Framework: {Framework}
Category: {Category}
Description: {Description}
SLA: {SLA} hours

Required Action: Immediate review and assignment
Link: {RecordURL}
```

**HIGH Alert**:
```
Subject: ⚠️ HIGH Priority Compliance Gap: {GapName}
Body:
A high priority gap requires attention:

Framework: {Framework}
SLA: {SLA} hours
Assigned To: {Owner}

Link: {RecordURL}
```

### Escalation Path

**Level 1**: Compliance Team (auto-assigned via Assignment Rules)
- Response: Acknowledge within 1 hour
- Action: Review and assign to appropriate specialist

**Level 2**: Compliance Manager (escalated if SLA > 50%)
- Response: Immediate
- Action: Prioritize resources, provide guidance

**Level 3**: CISO (escalated if CRITICAL severity AND SLA > 75%)
- Response: Immediate
- Action: Executive decision on resource allocation

### Gap Monitoring Queries

#### Overdue Gaps

```sql
SELECT Id, Name, Framework__c, Severity__c, SLA_Hours__c,
       CreatedDate, Owner.Name
FROM Compliance_Gap__c
WHERE Status__c NOT IN ('Resolved', 'Closed')
  AND SLA_Hours__c < 0
ORDER BY Severity__c, SLA_Hours__c
```

#### Gaps by Framework (Last 30 Days)

```sql
SELECT Framework__c, COUNT(Id), AVG(Resolution_Time_Hours__c)
FROM Compliance_Gap__c
WHERE CreatedDate = LAST_N_DAYS:30
GROUP BY Framework__c
ORDER BY COUNT(Id) DESC
```

#### Compliance Score Trend

```sql
SELECT Framework__c, Score__c, Score_Date__c
FROM Compliance_Score__c
WHERE Score_Date__c = LAST_N_MONTHS:3
ORDER BY Framework__c, Score_Date__c
```

---

## Scheduled Jobs

### Critical Elaro Scheduled Jobs

| Job Name | Frequency | Purpose | Critical? |
|----------|-----------|---------|-----------|
| ElaroAuditTrailPoller | Every 15 min | Poll Salesforce audit trail | Yes |
| RetentionEnforcementScheduler | Daily 2 AM EST | Enforce data retention policies | Yes |
| ConsentExpirationScheduler | Daily 3 AM EST | Check consent expiration | Yes |
| ElaroCCPASLAMonitorScheduler | Hourly | Monitor CCPA request SLA | Yes |
| ElaroGLBAAnnualNoticeBatch | Yearly | Send GLBA annual privacy notice | Yes |
| ComplianceScoreSnapshotScheduler | Daily 1 AM EST | Capture compliance score snapshot | Yes |
| AccessReviewScheduler | Monthly 1st | Trigger quarterly access reviews | Yes |
| BreachDeadlineMonitor | Hourly | Monitor breach notification deadlines | Yes |
| WeeklyScorecardScheduler | Weekly Mon 8 AM | Email weekly compliance scorecard | No |
| ElaroISO27001QuarterlyScheduler | Quarterly | ISO 27001 quarterly review | No |

### Job Monitoring

#### Verify Jobs Running

```sql
SELECT Id, CronJobDetail.Name, State, NextFireTime, PreviousFireTime
FROM CronTrigger
WHERE CronJobDetail.Name LIKE 'Elaro%'
ORDER BY CronJobDetail.Name
```

**Expected State**: `WAITING` or `RUNNING`
**Red Flag**: `PAUSED`, `BLOCKED`, `DELETED`

#### Check Job Failures

```sql
SELECT Id, CronJobDetail.Name, Status, NumberOfErrors,
       CreatedDate, CompletedDate
FROM AsyncApexJob
WHERE JobType = 'ScheduledApex'
  AND ApexClass.Name LIKE 'Elaro%'
  AND Status = 'Failed'
  AND CreatedDate = LAST_N_DAYS:7
ORDER BY CreatedDate DESC
```

#### Job Execution History

```sql
SELECT Id, ApexClass.Name, Status, TotalJobItems,
       JobItemsProcessed, NumberOfErrors, CreatedDate
FROM AsyncApexJob
WHERE ApexClass.Name LIKE 'Elaro%'
  AND CreatedDate = LAST_N_DAYS:7
ORDER BY CreatedDate DESC
LIMIT 100
```

### Troubleshooting Failed Jobs

#### Job Shows "Failed" Status

**Investigation Steps**:
1. Query AsyncApexJob for error details:
```sql
SELECT Id, ApexClass.Name, ExtendedStatus, CreatedDate
FROM AsyncApexJob
WHERE Id = 'JOB_ID'
```

2. Check debug logs for the job execution
3. Review governor limit usage
4. Check for data integrity issues

**Common Failures**:
- **FIELD_CUSTOM_VALIDATION_EXCEPTION**: Validation rule blocked operation
- **REQUIRED_FIELD_MISSING**: Missing required field value
- **CPU_TIME_LIMIT_EXCEEDED**: Optimize batch size
- **UNABLE_TO_LOCK_ROW**: Record locking conflict

#### Job Stuck in "Processing" State

**Symptoms**:
- Job shows "Processing" for >2 hours
- Progress not advancing

**Resolution**:
```sql
-- Abort the job
System.abortJob('JOB_ID');

-- Re-schedule manually
System.schedule('JobName', '0 0 2 * * ?', new SchedulerClass());
```

#### Job Not Executing (NextFireTime in Past)

**Symptoms**:
- NextFireTime is in the past
- Job hasn't run in >24 hours

**Resolution**:
1. Delete current scheduled job:
```apex
CronTrigger ct = [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name = 'JobName'];
System.abortJob(ct.Id);
```

2. Re-create job via Execute Anonymous:
```apex
System.schedule('JobName', 'CRON_EXPRESSION', new SchedulerClass());
```

---

## Dashboard Setup

### 1. Compliance Dashboard

**URL**: `/lightning/n/Compliance_Dashboard`

**Widgets**:

| Widget | Data Source | Refresh | Critical? |
|--------|-------------|---------|-----------|
| Compliance Gaps by Framework | Compliance_Gap__c | Real-time | Yes |
| Gaps by Severity | Compliance_Gap__c | Real-time | Yes |
| SLA Compliance Rate | Compliance_Gap__c | Hourly | Yes |
| Audit Trail Summary | Elaro_Audit_Log__c | Every 15 min | Yes |
| Framework Compliance Scores | Compliance_Score__c | Daily | No |
| Gap Remediation Velocity | Compliance_Gap__c | Daily | No |

**Setup Steps**:
1. Setup → Lightning App Builder
2. Open "Compliance Dashboard" page
3. Verify all components are active
4. Set as default homepage for "Elaro" app
5. Assign to appropriate user profiles

### 2. System Monitor Dashboard

**URL**: `/lightning/n/System_Monitor`

**Widgets**:

| Widget | Data Source | Refresh | Alert Threshold |
|--------|-------------|---------|----------------|
| SOQL Queries Gauge | Governor_Limit_Snapshot__c | Real-time | 80% |
| DML Statements Gauge | Governor_Limit_Snapshot__c | Real-time | 80% |
| CPU Time Gauge | Governor_Limit_Snapshot__c | Real-time | 75% |
| Heap Size Gauge | Governor_Limit_Snapshot__c | Real-time | 70% |
| API Usage Trend | API_Usage_Snapshot__c | Hourly | 80% |
| Error Log Summary | ApexLog | Real-time | >10 errors |

**Setup Steps**:
1. Assign "Elaro System Admin" permission set to ops team
2. Navigate to System Monitor Dashboard
3. Click "Edit Page" if customization needed
4. Configure alert thresholds per widget
5. Set email alerts for threshold breaches

### 3. Executive KPI Dashboard

**URL**: `/lightning/n/Executive_KPIs`

**Widgets**:

| Widget | Metric | Target | Status Indicator |
|--------|--------|--------|------------------|
| Overall Compliance Score | Average across all frameworks | 95% | Green >90%, Yellow 80-90%, Red <80% |
| Framework Compliance Breakdown | Score per framework | 90% per framework | Color-coded by framework |
| Risk Trend Analysis | Gap count over time | Decreasing trend | Green if decreasing |
| Remediation Velocity | Gaps closed per week | >20 per week | Green if on target |
| Audit Readiness Score | Evidence coverage | 95% | Green >90% |
| Open Critical Gaps | Count of CRITICAL severity | 0 | Red if >0 |

**Setup Steps**:
1. Assign to executive user profiles
2. Schedule automated email delivery (weekly)
3. Configure drill-down links to detailed reports

---

## Alert Configuration

### Alert Priority Matrix

| Priority | Channels | Response Time | Example |
|----------|----------|---------------|---------|
| P1 - CRITICAL | Slack + Email + SMS | 15 minutes | CRITICAL compliance gap, Security breach, System down |
| P2 - HIGH | Slack + Email | 1 hour | HIGH priority gap, Governor limit at 90%, Scheduled job failure |
| P3 - MEDIUM | Email | 4 hours | MEDIUM priority gap, Warning threshold reached |
| P4 - LOW | Email digest | 24 hours | LOW priority gap, Informational alerts |

### Email Alert Setup

**Setup Location**: Setup → Email Alerts

**Template: Governor Limit Alert**
```
Subject: [P2] Elaro Governor Limit Alert - {LimitType}

Body:
A governor limit has exceeded the alert threshold:

Limit Type: {LimitType}
Current Value: {CurrentValue}
Maximum Value: {MaxValue}
Percentage Used: {PercentageUsed}%
Threshold: {ThresholdPercentage}%

Context: {Context}
Timestamp: {Timestamp}

Action Required:
1. Review recent apex executions
2. Identify offending classes
3. Optimize code if pattern persists

View Dashboard: {SystemMonitorURL}
```

**Template: Critical Compliance Gap**
```
Subject: [P1] 🚨 CRITICAL Compliance Gap Identified

Body:
A critical compliance gap requires immediate attention:

Gap Name: {GapName}
Framework: {Framework}
Category: {Category}
Severity: CRITICAL
SLA: {SLA} hours remaining

Description:
{Description}

Impact:
{ImpactDescription}

Required Actions:
1. Assign to compliance specialist immediately
2. Assess remediation options
3. Update status within 1 hour

View Gap: {RecordURL}
Compliance Dashboard: {DashboardURL}

This is an automated alert from Elaro Compliance Platform.
```

### Slack Integration

**Setup Steps**:
1. Create Slack app at api.slack.com
2. Enable Incoming Webhooks
3. Copy Webhook URL
4. Setup → Elaro AI Settings → Slack Webhook URL
5. Test with "Send Test Alert" button

**Alert Format**:
```json
{
  "text": "⚠️ *Elaro Alert*",
  "blocks": [
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "*Alert Type:* Governor Limit\n*Severity:* HIGH\n*Limit Type:* SOQL Queries\n*Percentage:* 85%"
      }
    },
    {
      "type": "actions",
      "elements": [
        {
          "type": "button",
          "text": {"type": "plain_text", "text": "View Dashboard"},
          "url": "https://yourorg.lightning.force.com/..."
        }
      ]
    }
  ]
}
```

### PagerDuty Integration (Optional)

**Use Case**: On-call rotation for P1 incidents

**Setup Steps**:
1. Create PagerDuty service
2. Copy Integration Key
3. Setup → Elaro AI Settings → PagerDuty Integration Key
4. Configure escalation policy
5. Test incident triggering

---

## Audit Trail Management

### Retention Policy

| Data Type | Retention Period | Archive Location |
|-----------|------------------|------------------|
| Audit Logs | 7 years | AWS S3 Glacier |
| Compliance Gaps | 10 years | Salesforce Big Objects |
| Compliance Evidence | 10 years | Salesforce Files + S3 |
| API Usage Snapshots | 2 years | Salesforce Big Objects |
| Governor Limit Snapshots | 1 year | CSV export to S3 |

### Audit Log Queries

#### Recent Compliance Actions

```sql
SELECT Id, Action__c, Object__c, User__c, Timestamp__c, Details__c
FROM Elaro_Audit_Log__c
WHERE Action__c IN ('COMPLIANCE_GAP_CREATED', 'COMPLIANCE_GAP_RESOLVED', 'EVIDENCE_UPLOADED')
  AND Timestamp__c = LAST_N_DAYS:7
ORDER BY Timestamp__c DESC
```

#### GDPR Erasure Requests

```sql
SELECT Id, Action__c, Record_Id__c, User__c, Timestamp__c, Details__c
FROM Elaro_Audit_Log__c
WHERE Action__c = 'GDPR_ERASURE'
  AND Timestamp__c = LAST_N_MONTHS:12
ORDER BY Timestamp__c DESC
```

#### PCI Access Violations

```sql
SELECT Id, Action__c, User__c, Timestamp__c, Details__c
FROM Elaro_Audit_Log__c
WHERE Action__c = 'PCI_ACCESS_VIOLATION'
  AND Timestamp__c = LAST_N_DAYS:30
ORDER BY Timestamp__c DESC
```

### Archive Procedure (Quarterly)

**Run quarterly on the 1st of Jan, Apr, Jul, Oct**

```bash
# Export audit logs older than 90 days
sf data export tree \
  --query "SELECT Id, Action__c, Object__c, User__c, Timestamp__c, Details__c FROM Elaro_Audit_Log__c WHERE Timestamp__c < LAST_N_DAYS:90" \
  --target-org production \
  --output-dir exports/audit-logs-$(date +%Y-Q%q)

# Upload to S3
aws s3 cp exports/audit-logs-$(date +%Y-Q%q)/ \
  s3://elaro-archives/audit-logs/$(date +%Y-Q%q)/ \
  --recursive

# Verify upload
aws s3 ls s3://elaro-archives/audit-logs/$(date +%Y-Q%q)/

# Delete archived records from Salesforce (optional - check retention policy first)
# sf data delete bulk --sobject Elaro_Audit_Log__c --file delete-ids.csv
```

---

## Performance Monitoring

### Key Performance Indicators

| Metric | Target | Alert Threshold | Source |
|--------|--------|----------------|--------|
| Dashboard Load Time | <3 seconds | >5 seconds | Real User Monitoring |
| API Response Time | <500ms | >2 seconds | API_Usage_Snapshot__c |
| Batch Job Duration | <30 minutes | >60 minutes | AsyncApexJob |
| SOQL Query Count (avg) | <50 per transaction | >80 per transaction | Governor_Limit_Snapshot__c |
| CPU Time (avg) | <3000ms per transaction | >7500ms per transaction | Governor_Limit_Snapshot__c |

### Performance Queries

#### Slow API Requests (Last 24 Hours)

```sql
SELECT Id, Request_Path__c, Duration_Milliseconds__c, Timestamp__c
FROM API_Usage_Snapshot__c
WHERE Duration_Milliseconds__c > 2000
  AND Timestamp__c = LAST_N_DAYS:1
ORDER BY Duration_Milliseconds__c DESC
LIMIT 50
```

#### Batch Job Performance

```sql
SELECT Id, ApexClass.Name, TotalJobItems, JobItemsProcessed,
       CreatedDate, CompletedDate,
       (CompletedDate - CreatedDate) Duration_Minutes
FROM AsyncApexJob
WHERE JobType IN ('BatchApex', 'ScheduledApex')
  AND CreatedDate = LAST_N_DAYS:7
ORDER BY Duration_Minutes DESC
```

---

## Troubleshooting

### Common Issues

#### Issue #1: Dashboard Not Loading

**Symptoms**:
- Blank dashboard
- Spinner indefinitely
- Console error: "Timeout"

**Investigation**:
1. Check browser console (F12)
2. Check governor limits dashboard
3. Query audit logs for errors

**Resolution**:
```sql
-- Check for recent errors in apex logs
SELECT Id, Request, Status, DurationMilliseconds
FROM ApexLog
WHERE Request LIKE '%ComplianceDashboard%'
  AND Status = 'Failure'
  AND CreatedDate = TODAY
```

#### Issue #2: Scheduled Job Not Running

**Symptoms**:
- NextFireTime in the past
- No execution records

**Investigation**:
```sql
SELECT Id, CronJobDetail.Name, State, NextFireTime
FROM CronTrigger
WHERE CronJobDetail.Name = 'JobName'
```

**Resolution**: See "Scheduled Jobs → Troubleshooting" section above

#### Issue #3: High Governor Limit Usage

**Symptoms**:
- Frequent limit alerts
- Performance degradation

**Investigation**: See "Governor Limit Monitoring → Troubleshooting" section above

---

## Maintenance Procedures

### Weekly Maintenance

- [ ] Review governor limit violations
- [ ] Check scheduled job execution status
- [ ] Review audit trail for anomalies
- [ ] Verify dashboard performance
- [ ] Check alert configurations
- [ ] Review open compliance gaps

### Monthly Maintenance

- [ ] Review and update alert thresholds
- [ ] Analyze compliance score trends
- [ ] Archive old audit logs (if >90 days)
- [ ] Review user access and permissions
- [ ] Update documentation
- [ ] Compliance gap retrospective

### Quarterly Maintenance

- [ ] Full security audit
- [ ] Performance optimization review
- [ ] Archive old data (audit logs, snapshots)
- [ ] Disaster recovery drill
- [ ] Review and update runbooks
- [ ] Stakeholder feedback session

---

## Emergency Procedures

### System Outage

1. Check Salesforce Trust (https://status.salesforce.com)
2. Verify org accessibility
3. Check governor limits dashboard
4. Review recent deployments
5. Escalate to Salesforce Support if needed

### Data Integrity Issue

1. Stop all scheduled jobs immediately
2. Investigate root cause
3. Restore from backup if needed
4. Contact Salesforce Support
5. Document incident and resolution

### Security Incident

1. Isolate affected systems
2. Notify security team immediately
3. Preserve evidence (audit logs, debug logs)
4. Follow incident response plan
5. Engage Salesforce Security team

---

## Contacts

| Role | Contact | Email | Phone |
|------|---------|-------|-------|
| Ops Team Lead | TBD | ops-team@solentra.com | TBD |
| Engineering Manager | TBD | engineering@solentra.com | TBD |
| Security Lead | TBD | security@solentra.com | TBD |
| Salesforce Support | Salesforce | - | 1-800-NO-SOFTWARE |

---

## Change Log

| Version | Date | Changes | Author |
|---------|------|---------|--------|
| 1.0 | 2026-02-02 | Initial operations guide | Claude Sonnet 4.5 |

---

**END OF GUIDE**
