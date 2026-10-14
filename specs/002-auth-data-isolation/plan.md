# Implementation Plan: User Authentication, Data Isolation & Invitations

**Branch**: `002-auth-data-isolation` | **Date**: 2026-10-12 | **Spec**: [specs/002-auth-data-isolation/spec.md](spec.md)

**Input**: Feature specification from `/specs/002-auth-data-isolation/spec.md`

## Summary

Implement federated Google SSO authentication, sliding 1-hour idle session management, strict per-user data isolation, and authenticated in-app peer invitations for the Idea Collector application. The React frontend utilizes Google Identity Services, manages authenticated state, provides an invitation form for inviting new Google emails, displays user-isolated idea lists with empty states, and preserves draft idea content upon session expiration. The Go backend Lambda validates Google ID tokens against Google's public JWKS, verifies and manages authorized accounts in DynamoDB (`IdeaCollector_Users`), creates sessions in DynamoDB (`IdeaCollector_Sessions`), isolates idea queries and ingestion via a Global Secondary Index (`UserIdeasIndex` on `IdeaCollector_Ideas`), and provides `POST /api/invitations` with duplicate and self-invitation safeguards.

## Technical Context

**Language/Version**: Go 1.22+ (Backend Lambda), TypeScript 5.6+ / React 19 (Frontend), Terraform 1.9+ (Infra)

**Primary Dependencies**:
- Backend: `github.com/aws/aws-lambda-go`, `github.com/aws/aws-sdk-go-v2` (`config`, `service/dynamodb`), `github.com/google/uuid`, standard library `crypto/rand`
- Frontend: Google Identity Services SDK (`window.google.accounts.id` or `@react-oauth/google`), React 19, Vite
- Infra: HashiCorp Terraform AWS Provider ~> 5.0

**Storage**: AWS DynamoDB (`IdeaCollector_Ideas` with `UserIdeasIndex` GSI, `IdeaCollector_Users`, `IdeaCollector_Sessions` with TTL enabled)

**Testing**: Go unit and contract tests (`go test ./...`), Frontend tests (Vitest / Testing Library), Terraform validate/plan

**Target Platform**: AWS Serverless (CloudFront, API Gateway HTTP API v2, Lambda on `provided.al2023`, DynamoDB)

**Project Type**: Full-Stack Web Application (Frontend SPA + Serverless Backend API + IaC)

**Performance Goals**: < 1.5s page load, < 1.0s API response, < 3s login and user idea listing (SC-004), < 1.5s idea submission confirmation (SC-007), < 1.5s invitation confirmation (SC-008)

**Constraints**:
- Enforce strict 1-hour idle session timeout (FR-011)
- Google SSO as exclusive identity provider (FR-002)
- Invite-only access model with in-app peer invitations and initial seed provisioning (FR-001, FR-003, FR-014)
- Duplicate and self-invitations prevented (FR-015)
- Ideas are append-only; editing and deleting deferred (Assumptions)
- Zero data leakage between users (FR-008, FR-009, SC-002)
- Zero application password storage or secrets committed (Constitution IV)

**Scale/Scope**: Idea Collector production service on `idea.dinhloc.dev`

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. AI-Native SDLC Pipeline**: PASS. Scope is strictly defined by `spec.md`; no speculative additions. Verification scenarios and acceptance criteria documented in `quickstart.md`.
- **II. Infrastructure as Code (IaC) & Remote State**: PASS. All AWS resources (DynamoDB tables, GSI, IAM role policies, API Gateway routes) are configured via Terraform in `apps/idea-collector/infra/`. No manual console interventions.
- **III. Automated Quality & CI/CD Gates**: PASS. Existing GitHub Actions pipelines and Nx targets will be used. Lint, typecheck, and unit tests will run prior to PR creation.
- **IV. Strict Security & Credential Handling**: PASS. Google SSO verification uses Google Client ID (public) and Google's public JWKS. No client secrets, passwords, or credentials stored or committed.
- **V. Codebase Respect & Localization**: PASS. Extends existing `apps/idea-collector/` structure without modifying unrelated projects or global configs.
- **Agent Constraints**: PASS. No modifications to CI/CD workflows or infrastructure state without explicit instruction.

*Post-Design Re-evaluation*: PASS. Phase 1 design artifacts (`research.md`, `data-model.md`, `contracts/api.yml`, `quickstart.md`) strictly conform to all constitutional rules.

## Project Structure

### Documentation (this feature)

```text
specs/002-auth-data-isolation/
├── checklists/
│   └── requirements.md
├── contracts/
│   └── api.yml          # Phase 1 output (OpenAPI 3.0 specification)
├── data-model.md        # Phase 1 output (Entities, DynamoDB schemas, validation rules)
├── plan.md              # This file (/speckit-plan command output)
├── quickstart.md        # Phase 1 output (Runnable validation guide)
├── research.md          # Phase 0 output (Architecture and technical decisions)
├── spec.md              # Feature specification
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
apps/
└── idea-collector/
    ├── backend/
    │   ├── auth/              # Google token verification (JWKS), session validator
    │   ├── handlers/          # HTTP handlers (auth, me, logout, invitations, ideas)
    │   ├── models/            # Domain entities and request/response DTOs
    │   ├── repository/        # DynamoDB access for Users, Sessions, and Ideas
    │   ├── go.mod
    │   ├── go.sum
    │   ├── main.go            # Request router and Lambda entrypoint
    │   └── Makefile
    ├── frontend/
    │   ├── src/
    │   │   ├── components/    # AuthPrompt, Header, IdeaForm, IdeaList, InviteForm, EmptyState
    │   │   ├── hooks/         # useAuth, useIdeas, useDraft, useInvitations
    │   │   ├── services/      # API client (Bearer auth, 401 error interceptor)
    │   │   ├── App.tsx
    │   │   ├── main.tsx
    │   │   └── vite-env.d.ts
    │   ├── project.json
    │   └── package.json
    └── infra/
        ├── main.tf            # DynamoDB tables & GSI, API GW routes (/api/invitations), Lambda IAM
        ├── variables.tf
        └── outputs.tf
```

**Structure Decision**: Web application layout under `apps/idea-collector/` maintaining separated `backend/`, `frontend/`, and `infra/` modules as established in Feature 001.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

*(No violations found)*
