# Scanner False-Positive Documentation for AppExchange Submission

Scanner: sf code-analyzer 5.13.0, rule selectors `AppExchange` + `Recommended:Security`,
workspaces `force-app` and `force-app-healthcheck`. Rule: PMD `ProtectSensitiveData`
(Moderate). The rule flags custom fields whose names match sensitive-data heuristics
("token", "passed", "signed", "hash", "access", "tier", "status", "public").
Each flagged field was inspected on 2026-07-08 at commit 4d0cec4. None stores a
credential, secret, or regulated personal data. No `<visibleLines>`/encryption change
is warranted; dispositions below are offered as review documentation.

| # | Field | Declared type | Disposition |
|---|-------|---------------|-------------|
| 1 | Deployment_Job__c.Tests_Passed__c | Number | Count of passing Apex tests in a deployment job. Not a password; name matches "pass" heuristic. |
| 2 | Elaro_Evidence_Anchor__c.Content_Hash__c | Text(64) | SHA-256 hex digest anchoring evidence integrity. One-way digest, not a key or credential. |
| 3 | Security_Incident__c.Assigned_To__c | Lookup(User) | Incident assignee reference. Standard ownership pattern. |
| 4 | Third_Party_Recipient__c.DPA_Signed__c | Checkbox | Boolean flag that a data processing agreement is signed. Stores no signature material. |
| 5 | Trust_Center_Link__c.Access_Count__c | Number | View counter telemetry. |
| 6 | Trust_Center_Link__c.Access_Tier__c | Picklist | Tier label (Public, Email_Gated, NDA_Required). |
| 7 | Trust_Center_Link__c.Last_Accessed_Date__c | DateTime | Access timestamp telemetry. |
| 8 | Trust_Center_Link__c.Link_Token__c | Text(36), unique, external ID | True positive detection, accepted by design. This is a shareable-link capability token: 128-bit value from Crypto.generateAesKey formatted as UUID (TrustCenterLinkService.generateUuid, force-app/main/default/classes/TrustCenterLinkService.cls:140). Validation enforces existence, Is_Active__c, and Expiration_Date__c under WITH USER_MODE (TrustCenterLinkService.cls:56-82); links are revocable (revokeLink); the guest-facing controller TrustCenterGuestController is declared `with sharing`. Equivalent to standard document-share-link tokens; storing it in plaintext is required for lookup and it grants only tier-scoped read access to Trust Center content. |
| 9 | Trust_Center_View__c.Certification_Status__c | Picklist | Certification display status. |
| 10 | Trust_Center_View__c.Is_Public__c | Checkbox | Visibility flag. |
| 11 | Workflow_Execution__c.Rules_Passed__c | Number | Count of passing workflow rules. |
