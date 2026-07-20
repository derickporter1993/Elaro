# Security Policy

## Supported Versions

The following versions of Elaro are currently supported with security updates:

| Version | Supported          | Salesforce API |
|---------| ------------------ | -------------- |
| 3.1.x   | :white_check_mark: | v66.0          |
| 3.0.x   | :white_check_mark: | v66.0          |
| 2.x     | :x:                | v60.0 - v63.0  |
| < 2.0   | :x:                | v58.0          |

Security patches are backported to the current major version (3.x) only. Users on older versions should upgrade to receive security updates.

## Reporting a Vulnerability

**Please do not file public issues for security vulnerabilities.** Instead, report them privately using one of these methods:

### Preferred: GitHub Security Advisories

1. Go to the [Security Advisories](https://github.com/derickporter1993/elaro/security/advisories) page
2. Click "New draft security advisory"
3. Provide a detailed description of the vulnerability, including:
   - Steps to reproduce
   - Impact assessment
   - Affected versions
   - Any suggested remediation

### Alternative: Email

If you cannot use GitHub Security Advisories, email **security@elaro.io** with:
- Subject line: `[SECURITY] Elaro - Brief description`
- Full details of the vulnerability
- Your contact information for follow-up questions

## Response Timeline

| Phase | Timeline | Description |
|-------|----------|-------------|
| Acknowledgment | Within 5 business days | We confirm receipt and assign a tracking ID |
| Initial Assessment | Within 10 business days | We validate the vulnerability and assess severity |
| Fix Development | Varies by severity* | We develop and test a fix |
| Disclosure | Coordinated with reporter | We publish the advisory and release the fix |

*Severity-based timelines:*
- **Critical** (RCE, data breach, authentication bypass): Fix within 14 days
- **High** (privilege escalation, sensitive data exposure): Fix within 30 days
- **Medium** (limited impact vulnerabilities): Fix within 60 days
- **Low** (defense-in-depth improvements): Fix within 90 days or next scheduled release

## Security Update Cadence

- **Critical/High**: Out-of-band release as soon as fix is ready
- **Medium/Low**: Bundled with next scheduled release
- **Dependency updates**: Monthly automated review via Dependabot

## Security Best Practices for Users

### 1. Keep Elaro Updated

Always run the latest supported version. Security patches are included in point releases:

```bash
sf package install --package "Elaro" --target-org <your-org>
```

### 2. Follow the Principle of Least Privilege

- Assign Elaro permissions via Permission Sets, not Profiles
- Grant only the permissions required for each user's role
- Regularly audit Elaro-related Permission Set assignments

### 3. Enable Salesforce Security Features

Elaro is designed to work with Salesforce security features:

- **Shield Platform Encryption**: Elaro respects encrypted fields
- **Event Monitoring**: Elaro integrates with Event Monitoring for audit trails
- **Transaction Security**: Elaro alerts can trigger Transaction Security policies
- **Field-Level Security (FLS)**: All queries use `WITH USER_MODE` to enforce FLS

### 4. Secure Your CI/CD Pipeline

If using Elaro CLI in CI/CD:

```bash
# Use JWT-based authentication (more secure than username/password)
sf org login jwt --client-id $SF_CLIENT_ID --jwt-key-file server.key --username $SF_USERNAME

# Never commit credentials
# Use environment variables or your CI/CD secret store
```

### 5. Monitor Trust Center

If you have published a Trust Center with Elaro:

- Review access logs regularly
- Rotate Trust Center access tokens quarterly
- Validate that only public-safe records are exposed

## Security Architecture

### Key Security Design Decisions

| Feature | Implementation |
|---------|---------------|
| SOQL Security | All queries use `WITH USER_MODE` |
| DML Security | All DML uses `as user` or `AccessLevel.USER_MODE` |
| Sharing Model | Explicit `with sharing` / `inherited sharing` on all classes |
| Dynamic SOQL | Admin-controlled Custom Metadata only; `AccessLevel.USER_MODE` enforced |
| Trust Center | Token-validated; returns public-safe records only |
| Secrets | Configured via Salesforce Named Credentials and Custom Metadata |
| Audit Logging | Structured logging via `ElaroLogger` (Platform Event persistence planned) |

### Known Security Considerations

The following are documented security considerations, not vulnerabilities:

1. **Dynamic SOQL from Custom Metadata** (`SOQLQueryEvaluator`): Compliance rules are stored in Custom Metadata and executed with `AccessLevel.USER_MODE`. Only users with "Customize Application" permission can modify Custom Metadata. This design is required for configurable compliance rules.

2. **OAuth Scope**: The Elaro CLI requests `api` and `refresh_token` scopes. The previous `full` scope has been deprecated in favor of minimal required scopes.

## Security Contacts

| Role | Contact | Response Time |
|------|---------|---------------|
| Security Team | security@elaro.io | 5 business days |
| Engineering Lead | engineering@elaro.io | 10 business days |

## Scope

This security policy covers:
- Elaro managed package (both main and Health Check packages)
- Elaro CLI and platform tooling
- Trust Center public access endpoints
- GitHub repository and CI/CD pipeline

This security policy does **not** cover:
- Salesforce platform security (report to Salesforce)
- Third-party integrations (report to respective vendors)
- Custom modifications made by customers

## Acknowledgments

We thank the security researchers and community members who have responsibly disclosed vulnerabilities. Your contributions make Elaro safer for everyone.

---

*Last updated: 2026-07-20*
*Policy version: 1.0*