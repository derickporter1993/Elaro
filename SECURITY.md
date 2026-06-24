# Security Policy

## Supported Versions

| Version | Supported |
| ------- | --------- |
| 3.x     | ✅ Active  |
| 2.x     | ⚠️ Security fixes only |
| < 2.0   | ❌ Unsupported |

## Reporting a Vulnerability

**Do not file public GitHub Issues for security vulnerabilities.**

Report vulnerabilities privately through one of the following channels:

1. **GitHub Security Advisories (preferred):** Open a [private security advisory](https://github.com/derickporter1993/Elaro/security/advisories/new) directly in this repository.
2. **Email:** Send details to `security@elaro.io` with the subject line `[SECURITY] <short description>`.

Include the following in your report:
- A description of the vulnerability and its potential impact
- Steps to reproduce (proof-of-concept code or screenshots if applicable)
- The affected component(s) and version(s)
- Any suggested mitigations or fixes

## Response SLAs

| Severity | Initial Acknowledgement | Status Update | Target Resolution |
| -------- | ----------------------- | ------------- | ----------------- |
| Critical | 1 business day          | 2 business days | 7 calendar days |
| High     | 2 business days         | 5 business days | 30 calendar days |
| Medium   | 5 business days         | 10 business days | 90 calendar days |
| Low      | 10 business days        | 30 business days | Next major release |

**Critical** — Remote code execution, authentication bypass, or data exfiltration with no user interaction.  
**High** — Privilege escalation, significant data exposure, or broken access controls requiring minimal interaction.  
**Medium** — Limited-scope data exposure, CSRF, or exploitable misconfigurations requiring user interaction.  
**Low** — Informational issues, minor information disclosure, or security hardening improvements.

## Disclosure Policy

Elaro follows **coordinated disclosure**:

1. Reporter submits vulnerability privately.
2. Elaro acknowledges receipt within the SLA above.
3. Elaro investigates and develops a fix.
4. Reporter is notified when a fix is ready for review.
5. Fix is released; a GitHub Security Advisory is published.
6. Reporter may disclose publicly 7 days after the fix is released (or sooner with Elaro's consent).

We will credit reporters in the advisory unless they prefer anonymity.

## Scope

In scope:
- Salesforce Apex classes and triggers in `force-app/` and `force-app-healthcheck/`
- Lightning Web Components (LWC) in `force-app/`
- Platform TypeScript packages under `platform/`
- CI/CD pipeline configurations

Out of scope:
- Third-party dependencies (report to the upstream maintainer; Elaro will apply updates)
- Issues that require physical access to a device
- Social engineering attacks

## Security Standards

Elaro follows these security standards in its implementation:

- All SOQL uses `WITH USER_MODE` or bind variables to prevent injection
- All DML enforces `AccessLevel.USER_MODE` or `as user` patterns
- External credentials stored in Named Credentials or Protected Custom Metadata only
- Field-Level Security enforced via `Security.stripInaccessible()` on all read/write operations
- No hardcoded credentials, tokens, or secrets in source code
- AppExchange security review compliance enforced in CI via Salesforce Code Analyzer
