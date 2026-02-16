# Development Constitution

Developers must adhere to this document for all activities related to coding, design, infrastructure, and operations.

## Core Principles

### I. Security as the Foundation

Security MUST be built-in, not added later. Security reviews MUST take place before every release, and all findings from security scanning tools MUST be addressed.

### II. Code Quality

Every line of code MUST meet production-grade standards. Code quality is measured using linters, static analysis tools, formatters, and other appropriate methods. Naturally, all code MUST comply with specifications.

### III. Design and Code, UI Standardization

All work MUST be standardized wherever possible. Developers should be able to perform the same tasks in the same way. Designs and code serving similar purposes should follow consistent patterns and structures.

### IV. Test Automation

While strict test-first development is not mandatory, automated tests MUST always be implemented. Overall test coverage MUST reach at least 80%, with 100% coverage required for critical paths.

### V. Performance by Design

Performance requirements should be defined upfront and continuously validated. However, optimizations must remain balanced—avoid premature or excessive optimization unless justified by clear performance needs.

### VI. Observability and Monitoring

All system components SHOULD be as observable as possible.

## Technical Summary

### Coding Standards

In all cases, you MUST comply with the common coding standard:

* `devdoc/coding-standard.md`

In addition, specific domain standards MUST also be followed:

* **Frontend**: `devdoc/frontend/coding-standard.md`
* **Infrastructure**: `devdoc/infrastructure/coding-standard.md`

### Testing Standards

* **Unit tests**: isolated, fast, deterministic
* **Integration tests**: validate contracts between components
* **End-to-end tests**: verify critical user journeys

## Development Workflow Policy

### Merge and Release

* All code changes require review, and automated checks MUST pass (linting, tests, and security scans) before merging.
* Documentation updates MUST accompany code changes.
* Releases SHOULD be automated as much as possible. Any manual steps require a documented migration plan.

### Quality Gates

* **Pre-merge**: automated checks, unit tests, code review
* **Pre-deploy**: integration tests, security scans, performance tests, smoke tests
