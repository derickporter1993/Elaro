# Elaro Documentation

Welcome to the Elaro documentation. This guide will help you find the information you need.

## Quick Links

- [CHANGELOG](CHANGELOG.md) - Version history and release notes
- [ROADMAP](ROADMAP.md) - Product roadmap and future plans

## Documentation Sections

### [User Documentation](user/)

Guides for end users, administrators, and operators.

- Installation and setup guides
- User and admin manuals
- Demo org configuration
- Operations guide

### [Developer Documentation](developer/)

Technical documentation for developers contributing to or integrating with Elaro.

- API reference
- Technical deep dive
- Data flows and external services
- Contributing guidelines
- Implementation design

### [Architecture](architecture/)

Architecture decision records (ADRs) and system design documentation.

- ADRs for major technical decisions
- UI/UX architecture
- System design patterns

### [Security](security/)

Security-related documentation and audit reports.

- FLS audit report
- Security review checklist
- Integration security reviews

### [AppExchange](appexchange/)

AppExchange submission and review documentation.

- App review materials
- Security review documentation
- AppExchange listing content
- Remediation plans

### [Audit Reports](audit/)

Current audit reports and findings (February 2026).

- Architecture audit
- Code quality audit
- LWC audit
- Security audit

### [Business](business/)

Business planning and alignment documentation.

- Business plan alignment

## Project Structure

```
elaro/
├── README.md              # Project readme
├── SECURITY.md            # Security policy
├── scripts/               # Utility scripts
├── examples/              # Sample files
├── force-app/             # Main Salesforce package
├── force-app-healthcheck/ # Health Check package (separate 2GP)
├── platform/              # TypeScript monorepo
└── docs/                  # This documentation (you are here)
```

## Contributing

See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines on contributing to Elaro.

## Need Help?

- **Technical Questions**: See [Developer Documentation](developer/)
- **Setup Issues**: See [User Documentation](user/)
- **Security Concerns**: See [SECURITY.md](../SECURITY.md)
- **AppExchange**: See [AppExchange Documentation](appexchange/)
