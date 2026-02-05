# System Architecture

## Overview

Elaro follows a layered architecture pattern with clear separation of concerns between the UI layer (LWC), service layer (Apex), and data layer (Salesforce objects). The architecture emphasizes security, scalability, and compliance with enterprise patterns.

## Architectural Layers

### 1. Presentation Layer (Lightning Web Components)

**Location**: `force-app/main/default/lwc/`

**Responsibilities**:

- User interface rendering
- Event handling
- Apex method invocation
- Client-side state management

**Key Components**:

- `elaroCopilot` - AI compliance assistant interface
- `complianceCopilot` - Alternative copilot UI
- `elaroDashboard` - Compliance dashboard with metrics
- `elaroSetupWizard` - Initial configuration wizard

**Architecture Patterns**:

- Component-based architecture
- Reactive properties with `@track` and `@wire`
- Event-driven communication
- Platform event subscriptions (where enabled)

**Security**:

- Lightning Locker enforced
- CSP (Content Security Policy) compliant
- Input validation on client and server

### 2. Controller Layer (AuraEnabled Services)

**Location**: `force-app/main/default/classes/*Controller.cls`, `*Service.cls`

**Responsibilities**:

- Expose functionality to LWC via `@AuraEnabled`
- Request validation and sanitization
- Response formatting for UI consumption
- Cache management

**Key Controllers**:

- `ElaroComplianceCopilot` - Main copilot interface (84 lines)
- `ElaroComplianceCopilotService` - AI service integration (567 lines)
- `ElaroDashboardController` - Dashboard data provider
- `ElaroComplianceScorer` - Compliance scoring engine (498 lines)

**Pattern**:

```java
@AuraEnabled(cacheable=true)
public static ScoreResult calculateReadinessScore() {
    // Input validation
    // Service delegation
    // Result caching
    // Error handling
}
```

### 3. Service Layer

**Location**: `force-app/main/default/classes/*Service.cls`, `*Base.cls`

**Responsibilities**:

- Business logic implementation
- Framework abstraction
- Transaction management
- Complex calculations and orchestration

**Service Architecture**:

#### Abstract Base Classes

- `ComplianceServiceBase` - Abstract base for all compliance frameworks
  - Policy caching
  - Gap management
  - Evidence collection
  - Framework-specific implementations extend this

#### Service Factory Pattern

- `ComplianceServiceFactory` - Creates appropriate service for framework
  - Supports: HIPAA, SOC2, NIST, FedRAMP, GDPR, SOX, PCI-DSS, CCPA, GLBA, ISO27001
  - Service locator pattern implementation

#### Framework Services

Each compliance framework has dedicated service:

- `ElaroHIPAAComplianceService`
- `ElaroSOC2ComplianceService`
- `ElaroGDPRComplianceService`
- `ElaroNISTComplianceService`
- `ElaroFedRAMPComplianceService`
- `ElaroSOXComplianceService`
- `ElaroPCIDSSComplianceService`
- `ElaroCCPAComplianceService`
- `ElaroGLBAComplianceService`
- `ElaroISO27001ComplianceService`

#### Integration Services

- `ElaroComplianceCopilotService` - Claude AI integration
- `SlackIntegration` - Slack notifications
- `JiraIntegrationService` - Jira issue tracking
- `ServiceNowIntegration` - ServiceNow incidents
- `PagerDutyIntegration` - PagerDuty escalation
- `TeamsNotifier` - Teams notifications

### 4. Utility Layer

**Location**: `force-app/main/default/classes/*Utils.cls`, `*Helper.cls`

**Key Utilities**:

- `ElaroSecurityUtils` - CRUD/FLS checking, secure queries (260 lines)
- `ElaroConstants` - Constants and enums (101 lines)
- `ElaroGraphIndexer` - Big Object indexing (326 lines)
- `ElaroEventProcessor` - Event processing (128 lines)
- `ElaroTestDataFactory` - Test data generation (164 lines)
- `ComplianceTestDataFactory` - Compliance test data (151 lines)
- `TriggerRecursionGuard` - Trigger recursion prevention (65 lines)

### 5. Data Access Layer

**Location**: Salesforce objects (standard and custom)

**Standard Objects Used**:

- Account
- User
- PermissionSet
- PermissionSetAssignment
- SetupAuditTrail
- EntityDefinition
- FieldDefinition

**Custom Objects**:

- `Compliance_Gap__c` - Identified compliance violations
- `Elaro_Evidence_Item__c` - Audit evidence
- `Elaro_Audit_Package__c` - Audit deliverables
- `Elaro_Compliance_Graph__b` - Historical graph data (Big Object)
- `Integration_Error__c` - Integration failure tracking
- `Access_Review__c` - ISO 27001 access reviews

**Custom Metadata**:

- `Compliance_Policy__mdt` - Framework policies and controls

**Custom Settings**:

- `Elaro_AI_Settings__c` - AI feature toggles and thresholds

## Design Patterns

### 1. Abstract Class Pattern

**Example**: `ComplianceServiceBase`

```java
public abstract with sharing class ComplianceServiceBase implements IRiskScoringService {
    public abstract String getFrameworkName();
    protected abstract List<Violation> evaluateControls();
    protected abstract Decimal getFrameworkMultiplier();
}
```

### 2. Factory Pattern

**Example**: `ComplianceServiceFactory`

```java
public static ComplianceServiceBase getService(String framework) {
    switch (framework) {
        case 'HIPAA': return new ElaroHIPAAComplianceService();
        case 'SOC2': return new ElaroSOC2ComplianceService();
        // ... etc
    }
}
```

### 3. Queueable Pattern

**Example**: Async processing with callouts

```java
public with sharing class ElaroSlackNotifierQueueable
    implements Queueable, Database.AllowsCallouts {

    public void execute(QueueableContext context) {
        // Retry logic
        // Callout handling
        // Error logging
    }
}
```

### 4. Cache Pattern

**Example**: Static caching for expensive queries

```java
private static ScoreFactor permissionSprawlCache;

private static ScoreFactor calculatePermissionSprawlScore() {
    if (permissionSprawlCache != null) {
        return permissionSprawlCache;
    }
    // Expensive query
    permissionSprawlCache = factor;
    return factor;
}
```

### 5. Strategy Pattern

**Example**: Framework-specific scoring strategies
Each framework service implements its own `evaluateControls()` and `getFrameworkMultiplier()` methods with different algorithms.

### 6. Template Method Pattern

**Example**: Audit flow in compliance services
Base class defines the algorithm, subclasses customize specific steps.

## Data Flow

### Compliance Assessment Flow

1. **Trigger/Schedule** → `ElaroComplianceScheduler`
2. **Framework Service** → `ComplianceServiceFactory.getService(framework)`
3. **Evaluation** → `service.evaluateCompliance()`
4. **Gap Creation** → `service.createGap()`
5. **Alert Generation** → `ElaroComplianceAlert`
6. **Notification** → Queueable → External API

### User Query Flow

1. **LWC Component** → User submits query
2. **Controller** → `@AuraEnabled` method
3. **Rate Limiting** → Platform Cache check
4. **AI Service** → `ElaroComplianceCopilotService`
5. **Claude API** → Named Credential callout
6. **Response Parsing** → JSON parsing
7. **Caching** → Cache results
8. **UI Update** → Return to LWC

### Event Processing Flow

1. **Platform Event** → (currently excluded from deploy)
2. **Trigger** → `ElaroEventCaptureTrigger`
3. **Processor** → `ElaroEventProcessor`
4. **Analysis** → Risk scoring
5. **Graph Indexing** → `ElaroGraphIndexer`
6. **Alerting** → If risk threshold exceeded

## Security Architecture

### Sharing Model

- **All Classes**: Use `with sharing` (enforced sharing rules)
- **Exceptions**: Queueable/Batch classes run in system context but respect sharing

### CRUD/FLS Enforcement

- **SecurityUtils**: Centralized CRUD/FLS checking
- **Schema Describe**: Runtime permission checking
- **WITH SECURITY_ENFORCED**: SOQL keyword for FLS
- **WITH USER_MODE**: User mode queries (newer classes)
- **stripInaccessible()**: Modern FLS protection

### Named Credentials

All external integrations use Named Credentials (no hardcoded secrets):

- `callout:Elaro_Claude_API`
- `callout:Slack_Webhook`
- `callout:Teams_Webhook`
- `callout:Jira_API`
- `callout:ServiceNow_API`
- `callout:PagerDuty_API`

### Encryption

- **Shield Platform Encryption**: Field-level encryption for sensitive data
- **HTTPS**: All external integrations
- **Secure Cookies**: Session management

## Scalability Patterns

### Governor Limit Management

- **Queueable Jobs**: Async processing for callouts
- **Batch Apex**: Large data volume processing
- **Limits Class**: Proactive limit checking
- **Aggregate Queries**: Efficient counting

### Caching Strategy

- **Platform Cache**: Org-level and session-level caching
- **Static Variables**: Transaction-level caching
- **Cache TTL**: 1-hour default for AI responses

### Bulkification

- **Collections**: Process records in bulk
- **Aggregate Queries**: Avoid individual queries
- **Relationship Queries**: Reduce query count

## Error Handling

### Structured Logging

```java
System.debug(LoggingLevel.ERROR,
    '[ClassName] Method: message - ' +
    'CorrelationId: ' + correlationId + ', ' +
    'Error: ' + e.getMessage());
```

### Exception Hierarchy

- `ElaroException` - Base exception class
- `ComplianceServiceException` - Service layer errors
- `SecurityException` - Security violations

### Error Tracking

- `Integration_Error__c` - Persistent error logging
- Correlation IDs - End-to-end tracing
- Stack traces - Debug context (test only)

## Performance Considerations

### Expensive Operations

- AI API calls (cached)
- Aggregate permission queries (cached)
- SetupAuditTrail queries (limited)
- PermissionSet queries (aggregate)

### Optimization Strategies

- Static caching for repeated calculations
- Cache partitioning by framework
- Async processing for non-critical paths
- Lazy loading for heavy objects

## Architectural Decisions

### Why Abstract Base Classes?

Provides consistent interface for all compliance frameworks while allowing framework-specific implementations.

### Why Queueable over @future?

Queueable provides better error handling, retry logic, chaining, and monitoring capabilities.

### Why Big Objects?

Compliance graph data requires historical tracking beyond standard object limits (Big Objects support millions of records).

### Why Named Credentials?

Centralized credential management, automatic authentication, and no secrets in code.

## Anti-Patterns Avoided

✅ No hardcoded IDs in production code (only test classes)
✅ No hardcoded secrets (all use Named Credentials)
✅ No `without sharing` classes (except noted issue)
✅ No SOQL in loops (bulkified)
✅ No DML in loops (bulkified)
✅ No synchronous callouts from triggers (all async)
