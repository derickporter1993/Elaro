# ProtectSensitiveData Disposition - 2026-06-20

Branch: `feature/elaro-submit-today-20260620`
Code Analyzer report: `/tmp/elaro-code-analyzer-cleanup-final.json`
Package surface: `force-app` only. The Health Check package (`force-app-healthcheck`) has no
remaining `ProtectSensitiveData` findings in the latest local AppExchange/Security scan.
Local disposition status: complete, pending org permission validation after Salesforce CLI auth
recovery.

## Rule Behavior

Salesforce Code Analyzer rule `ProtectSensitiveData` reports custom field metadata when a field API name contains auth-token-like terms. The installed PMD rule implementation is `DetectSecretsInCustomObjects`, and bytecode inspection shows that for standard custom objects ending in `__c`, the rule reports matching field names directly. It does not inspect field descriptions, compliance classification, or `securityClassification` metadata before reporting these `__c` object findings.

The relevant token list includes:

```text
KEY, ACCESS, PASS, ENCRYPT, TOKEN, HASH, SECRET, SIGNATURE, SIGN, AUTH,
AUTHORIZATION, AUTHENTICATION, AUTHENTICATE, BEARER, CRED, REFRESH, CERT,
PRIVATE, PUBLIC, JWT
```

## Disposition Matrix

| Field                                          | Trigger                  | Disposition                                                                                                                                   | Submission note                                                                                                                                                                                |
| ---------------------------------------------- | ------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Deployment_Job__c.Tests_Passed__c`            | `PASS`                   | False positive. Numeric aggregate count of passed Apex tests, not a password, token, credential, or secret.                                   | Keep field API name to avoid managed-package migration risk; explain as aggregate deployment telemetry.                                                                                        |
| `Workflow_Execution__c.Rules_Passed__c`        | `PASS`                   | False positive. Numeric aggregate count of compliance rules that evaluated successfully.                                                      | Keep field API name to preserve reporting semantics; explain as aggregate rule telemetry.                                                                                                      |
| `Elaro_Evidence_Anchor__c.Content_Hash__c`     | `HASH`                   | Security-sensitive integrity artifact, but not an auth credential. Hash value should remain access-controlled with the evidence object.       | Explain as SHA-256 integrity anchor, not authentication material. Confirm object/field permissions in org validation.                                                                          |
| `Security_Incident__c.Assigned_To__c`          | `SIGN` inside `Assigned` | False positive. Lookup to the internal user assigned to an incident, not a signature or signing secret.                                       | Explain token substring collision. Validate incident object permissions before submission.                                                                                                     |
| `Third_Party_Recipient__c.DPA_Signed__c`       | `SIGN` inside `Signed`   | False positive. Boolean compliance status indicating whether a data processing agreement exists.                                              | Explain compliance status boolean; confirm field visibility policy.                                                                                                                            |
| `Trust_Center_Link__c.Access_Count__c`         | `ACCESS`                 | False positive for credential storage, but access telemetry can be sensitive.                                                                 | Explain numeric view counter; confirm trust-center object permissions and retention policy.                                                                                                    |
| `Trust_Center_Link__c.Access_Tier__c`          | `ACCESS`                 | False positive for credential storage, but access tier controls disclosure behavior.                                                          | Explain restricted picklist for public/email-gated/NDA-required access tiers.                                                                                                                  |
| `Trust_Center_Link__c.Last_Accessed_Date__c`   | `ACCESS`                 | False positive for credential storage, but access telemetry can be sensitive.                                                                 | Explain timestamp telemetry; confirm object permissions and retention policy.                                                                                                                  |
| `Trust_Center_Link__c.Link_Token__c`           | `TOKEN`                  | Real security-sensitive field. The value is a UUID share token, not an OAuth/session/API token, but it grants access to trust-center content. | Before submission, validate token entropy, revocation, expiration, object/field permissions, logging redaction, and whether the token should be replaced by a protected/session-scoped design. |
| `Trust_Center_View__c.Certification_Status__c` | `CERT`                   | False positive. Picklist status for certification progress, not a certificate or credential.                                                  | Explain certification workflow status and confirm field visibility policy.                                                                                                                     |
| `Trust_Center_View__c.Is_Public__c`            | `PUBLIC`                 | False positive for secret storage. Boolean exposure flag used as a security control.                                                          | Explain that `true` is an intentional publication flag and validate all public controllers enforce it with `WITH USER_MODE`.                                                                   |

## Recommended Submission Position

Do not suppress these findings silently. Include this disposition with the security review materials and the Code Analyzer report.

## Local Security Review Closure

Local review found one actionable issue while validating the `Link_Token__c` disposition:
`TrustCenterLinkService.createLink` logged the full share token after record creation. That has
been fixed to log the `Trust_Center_Link__c` record Id instead, and `scripts/preflight.sh` now
fails if future Apex logger calls concatenate `Link_Token__c` into log output.

Evidence:

- RED: `npm run preflight` failed on `TrustCenterLinkService.cls` because the full
  `Link_Token__c` value was logged.
- GREEN: `npm run preflight` passed after the log message was changed to use the record Id.
- `TrustCenterGuestController` validates token existence, active status, expiration, and only
  returns `Trust_Center_View__c` records where `Is_Public__c = true`.
- `TrustCenterLinkServiceTest` covers token generation, invalid token rejection, expiration,
  revocation, access recording, and token uniqueness.
- `TrustCenterGuestControllerTest` covers valid access, invalid/blank/expired/revoked token
  rejection, public-only view filtering, access tier response, and access-count updates.

Recommended follow-up before final package upload:

1. Confirm permission sets and profiles expose these fields only to intended users.
2. Confirm public Trust Center controllers never log or expose full `Link_Token__c` values unnecessarily.
3. Confirm token lifecycle controls for `Trust_Center_Link__c.Link_Token__c`.
4. Re-run org deploy validation and Apex tests after Salesforce CLI auth recovery.
5. Re-run Code Analyzer and attach the final report plus this disposition.
