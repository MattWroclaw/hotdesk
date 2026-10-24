# HotDesk Constitution

A desk and conference room reservation system for hybrid office environments.

## Core Principles

### I. Specification-First Development

Specification is the source of truth. All development decisions, feature designs, and implementation choices must be validated against the approved specification. Do not implement features that are not specified or approved. Treat the approved specification and implementation plan as non-negotiable constraints.

### II. Simplicity & Maintainability

Prioritize clean, readable architecture and ease of maintenance over feature complexity. Avoid premature optimization and unnecessary abstractions. Apply YAGNI (You Aren't Gonna Need It) principles. Code must be understandable by current and future maintainers.

### III. Data Integrity & Booking Safety

No double bookings are permitted. The same desk or conference room cannot be reserved twice for the same time slot. Data integrity is enforced at both the database layer (constraints) and application layer (validation). Transaction handling for concurrent booking operations must be tested and verified.

### IV. Security & Access Control

All user input is validated. Access control is enforced consistently across the API. Authorization rules are checked before any data modification. No security compromises are acceptable regardless of project stage or timeline.

### V. Automated Testing

Business logic and booking rules must have automated test coverage. Test coverage includes normal scenarios, boundary conditions, and failure cases. Regression tests protect against unintended side effects. No quality gates are waived merely to make a build pass.

### VI. Incremental, Verifiable Delivery

Changes are small and independently verifiable. Implementation is broken into discrete tasks completed in dependency order. Each task is verified against its acceptance criteria before closure. Documentation and task status are updated to reflect actual implementation.

## Development Workflow & Quality Standards

### Development Process

1. Follow the Spec Driven Development workflow: Constitution → Specify → Clarify (when needed) → Plan → Tasks → Analyze → Implement.
2. Treat the approved specification and implementation plan as the source of truth.
3. Break implementation into small, independently verifiable tasks. Complete tasks in the defined order and update task status only after verification.
4. Before changing existing code, inspect the relevant files and understand their dependencies.
5. Keep documentation, API contracts, database models, and tests consistent with the approved specification.
6. Use Git commits at meaningful milestones so changes can be reviewed and reverted.
7. Ask for clarification when requirements are ambiguous instead of making significant assumptions.

### Code Review Process

1. Review every implementation change against the relevant specification and acceptance criteria.
2. Check code for correctness, readability, maintainability, security, and unnecessary complexity.
3. Review database constraints and transaction handling for booking operations.
4. Verify that API validation, error handling, and access control are implemented consistently.
5. Review test coverage for normal scenarios, boundary conditions, and failure cases.
6. Document unresolved issues and do not claim a task is complete while required acceptance criteria remain unmet.

### Quality Gates

A task or milestone may be marked complete only when all applicable conditions are satisfied:

1. All acceptance criteria for the task are met.
2. Relevant automated tests pass.
3. Backend tests use pytest; frontend tests cover important UI behavior and user interactions.
4. Booking tests verify that the same desk cannot be booked twice for the same date, including conflicting concurrent requests where applicable.
5. Database constraints enforce critical integrity rules; application-level checks alone are insufficient.
6. Input validation, error handling, and authorization are tested where relevant.
7. No known critical security issues or exposed credentials are introduced.
8. The application starts successfully and the affected functionality has been verified.
9. Documentation and task status are updated to reflect the actual implementation.

Do not skip tests, weaken assertions, or change acceptance criteria merely to make a build pass. If a quality gate cannot be completed, report the limitation explicitly.

## Technology & Deployment

- **Backend**: Python with FastAPI
- **Frontend**: React with TypeScript
- **Database**: SQLite for the initial version
- **Deployment**: Local Windows development first; server deployment will be planned later
- **Architecture**: Modular design suitable for a small business application
- **Dependencies**: No additional infrastructure or dependencies without a clear requirement

## Governance

The HotDesk Constitution is the highest authority for all development decisions. All contributions must comply with these principles and standards. Amendments to this constitution require documentation, justification, and explicit approval. Constitution compliance is verified in code reviews and pull requests before integration.

**Version**: 1.0.0 | **Ratified**: 2026-10-21 | **Last Amended**: 2026-10-21
