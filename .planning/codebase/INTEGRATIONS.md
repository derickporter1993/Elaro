# External Integrations

## Overview

Elaro integrates with multiple external services for notifications, incident management, AI processing, and audit workflows. All integrations use Named Credentials for secure authentication management.

## Named Credentials

All external API authentication is managed through Salesforce Named Credentials:

| Named Credential   | Service          | Purpose                                          | Authentication   |
| ------------------ | ---------------- | ------------------------------------------------ | ---------------- |
| `Elaro_Claude_API` | Anthropic Claude | AI compliance analysis, natural language queries | API Key          |
| `Slack_Webhook`    | Slack            | Real-time notifications and alerts               | Webhook URL      |
| `Teams_Webhook`    | Microsoft Teams  | Real-time notifications and alerts               | Webhook URL      |
| `Jira_API`         | Atlassian Jira   | Issue tracking and audit management              | OAuth/Basic Auth |
| `ServiceNow_API`   | ServiceNow       | IT service management integration                | OAuth/Basic Auth |
| `PagerDuty_API`    | PagerDuty        | Incident management and escalation               | API Token        |

## Integration Details

### 1. Anthropic Claude API

**Named Credential**: `callout:Elaro_Claude_API`

**Purpose**: AI-powered compliance analysis and natural language processing

**Services Using Integration**:

- `RootCauseAnalysisEngine.cls` - Root cause analysis via AI
- `NaturalLanguageQueryService.cls` - Natural language compliance queries
- `ElaroComplianceCopilotService.cls` - Compliance copilot AI service
- `ElaroGraphIndexer.cls` - Risk prediction (Einstein fallback)

**Model Used**: `claude-sonnet-4-20250514`

**Key Features**:

- Event pattern analysis
- Compliance recommendations
- Risk predictions
- Audit summaries
- Event categorization

**Implementation Pattern**:

```java
HttpRequest req = new HttpRequest();
req.setEndpoint('callout:Elaro_Claude_API');
req.setMethod('POST');
req.setHeader('Content-Type', 'application/json');
req.setHeader('anthropic-version', '2023-06-01');
req.setTimeout(60000);
```

**Cache Configuration**:

- Cache Partition: `local.ElaroCache`
- TTL: 3600 seconds (1 hour)
- Caches recommendations and predictions

### 2. Slack Integration

**Named Credential**: `callout:Slack_Webhook`

**Purpose**: Real-time compliance alerts and notifications

**Services Using Integration**:

- `SlackNotifier.cls` - Primary Slack notification service
- `SlackIntegration.cls` - Advanced Slack features (rich messages, actions)
- `ElaroSlackNotifierQueueable.cls` - Queueable Slack notifications
- `ElaroComplianceAlert.cls` - Alert notifications
- `ElaroDailyDigest.cls` - Daily compliance digests

**Notification Types**:

- Compliance alerts (CRITICAL, HIGH, MEDIUM, LOW severity)
- Performance alerts (governor limit warnings)
- Audit package notifications
- Daily compliance digests
- Incident escalations

**Rich Message Features**:

- Slack Block Kit for rich formatting
- Interactive buttons (View in Salesforce)
- Color-coded severity indicators
- Field-rich notifications

**Implementation Pattern**:

```java
// Queueable (recommended)
ElaroSlackNotifierQueueable job = new ElaroSlackNotifierQueueable(jsonPayload, correlationId);
System.enqueueJob(job);

// @future (legacy support)
@future(callout=true)
public static void sendAlert(String text) {
    HttpRequest req = new HttpRequest();
    req.setEndpoint('callout:Slack_Webhook');
    req.setMethod('POST');
    req.setBody(jsonPayload);
}
```

### 3. Microsoft Teams Integration

**Named Credential**: `callout:Teams_Webhook`

**Purpose**: Teams channel notifications for compliance alerts

**Services Using Integration**:

- `TeamsNotifier.cls` - Teams notification service
- `ElaroTeamsNotifierQueueable.cls` - Queueable Teams notifications

**Implementation**: Similar to Slack, using Queueable pattern with retry logic

### 4. Jira Integration

**Named Credential**: `callout:Jira_API`

**Purpose**: Issue tracking for compliance gaps and audit findings

**Services Using Integration**:

- `JiraIntegrationService.cls` - Full Jira integration

**Features**:

- Create issues from compliance gaps
- Link Salesforce records to Jira issues
- Sync issue status
- Transition issues through workflow
- Bulk create/update operations

**API Version**: REST API v3

**Implementation Pattern**:

```java
private static HttpResponse makeCallout(String method, String endpoint, String body) {
    HttpRequest req = new HttpRequest();
    req.setEndpoint('callout:Jira_API' + API_VERSION + endpoint);
    req.setMethod(method);
    req.setHeader('Content-Type', 'application/json');
    req.setBody(body);
    return new Http().send(req);
}
```

### 5. ServiceNow Integration

**Named Credential**: `callout:ServiceNow_API`

**Purpose**: IT service management integration for compliance incidents

**Services Using Integration**:

- `ServiceNowIntegration.cls` - ServiceNow incident management

**Features**:

- Create incidents from compliance alerts
- Update incident status
- Link evidence to incidents
- Priority-based escalation

### 6. PagerDuty Integration

**Named Credential**: `callout:PagerDuty_API`

**Purpose**: Incident management and on-call escalation for critical compliance violations

**Services Using Integration**:

- `PagerDutyIntegration.cls` - PagerDuty incident triggering

**Features**:

- Trigger incidents for CRITICAL violations
- Auto-resolve on remediation
- Acknowledgment tracking
- Escalation policies

## Integration Architecture

### Async Processing Pattern

All external integrations use asynchronous processing to avoid blocking transactions:

**Queueable Apex (Preferred)**:

```java
public with sharing class ElaroSlackNotifierQueueable
    implements Queueable, Database.AllowsCallouts {
    // Retry logic with exponential backoff
    // Error handling and logging
    // Correlation tracking
}
```

**@future Methods (Legacy)**:

- Used for backward compatibility
- Cannot be called from Queueable/Batch context
- No retry capability

### Error Handling

All integrations implement structured error handling:

1. **Correlation IDs**: Track requests across systems
2. **Integration Error Logging**: `Integration_Error__c` custom object
3. **Retry Logic**: Exponential backoff for Queueable jobs
4. **Fallback Behavior**: Degrade gracefully on failure

### Security

- **Named Credentials**: Secure credential storage (no hardcoded secrets)
- **Sharing Rules**: All integration classes use `with sharing`
- **Field Level Security**: Respects FLS in all DML operations
- **OWD**: Respects organization-wide defaults

## Integration Testing

### Mock Classes

Each integration has corresponding test classes with HTTP callout mocks:

- `SlackIntegrationTest.cls` - Slack mock testing
- `JiraIntegrationServiceTest.cls` - Jira mock testing
- `ServiceNowIntegrationTest.cls` - ServiceNow mock testing
- `PagerDutyIntegrationTest.cls` - PagerDuty mock testing

### Mock Pattern

```java
private class MockSlackAPI implements HttpCalloutMock {
    public HttpResponse respond(HttpRequest req) {
        HttpResponse res = new HttpResponse();
        res.setStatusCode(200);
        res.setBody('{"ok": true}');
        return res;
    }
}

Test.setMock(HttpCalloutMock.class, new MockSlackAPI());
```

## Data Flow

### Alert Flow

1. Compliance violation detected
2. `ElaroComplianceAlert` creates alert record
3. Alert severity determines notification channels
4. Queueable job enqueued for each channel
5. External API called via Named Credential
6. Response logged, errors tracked in `Integration_Error__c`

### AI Analysis Flow

1. User requests analysis via LWC component
2. `ElaroComplianceCopilotService` processes request
3. Cache checked for existing results
4. Claude API called via Named Credential
5. Response parsed and cached
6. Results returned to LWC component

## Configuration

### Org-Wide Settings

Managed via `Elaro_AI_Settings__c` custom settings:

- `Enable_AI_Reasoning__c` - Toggle AI features
- `Confidence_Threshold__c` - AI confidence threshold
- `Auto_Remediate__c` - Enable automatic remediation

### Per-Integration Settings

Most integrations read settings from:

- Custom Metadata Types
- Custom Settings
- Environment variables (via Named Credentials)

## Monitoring

### Integration Health

- **Debug Logs**: All integrations log with `LoggingLevel.ERROR` on failures
- **Integration_Error\_\_c**: Persistent error tracking
- **Correlation IDs**: End-to-end request tracing

### Metrics

- Success/failure rates
- Average response times
- Queue depth for Queueable jobs
- API rate limit usage

## Future Integrations

### Planned

- **Einstein Platform**: Risk prediction (TODO in `ElaroGraphIndexer`)
- **GitHub**: Audit trail integration
- **Azure DevOps**: Work item synchronization

### Under Consideration

- **Email**: SMTP for compliance reports
- **SMS**: Twilio for critical alerts
- **Webhooks**: Generic webhook support for custom integrations
