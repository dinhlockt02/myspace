# Implementation Plan: Public User Registration & Google Authentication with AWS Cognito

**Branch**: `008-public-registration-google-auth` | **Date**: 2026-10-15 | **Spec**: [spec.md](file:///home/loctran/coding/myspace/specs/008-public-registration-google-auth/spec.md)

**Input**: Feature specification from `/specs/008-public-registration-google-auth/spec.md`

## Summary

Transition Idea Collector to open public self-registration via a prominent "Sign in with Google" button, backed by an AWS Cognito User Pool as the central user directory with Google as a federated Social Identity Provider. When a visitor signs in via Google for the first time, Cognito provisions their account automatically (Just-In-Time) and issues JWT tokens. The React 19 frontend performs OAuth2 PKCE authorization routing directly to Google, stores tokens, and renders the user's isolated workspace without intermediate onboarding screens. AWS API Gateway HTTP API v2 enforces edge authorization via a native JWT Authorizer tied to the Cognito User Pool. DynamoDB `IdeaCollector_Ideas` partitions ideas by Cognito `sub`, and the legacy user invitation interface and endpoints are decommissioned.

## Technical Context

**Language/Version**: Go 1.26 (Backend Lambda), TypeScript 5.7+ / React 19 (Frontend SPA), Terraform 1.9+ (IaC)

**Primary Dependencies**:
- Backend: `github.com/aws/aws-lambda-go`, `github.com/aws/aws-sdk-go-v2` (`config`, `service/dynamodb`), `github.com/google/uuid`
- Frontend: React 19, Vite 6.2, Web Crypto API (`crypto.subtle` for PKCE)
- Infra: HashiCorp Terraform AWS Provider ~> 5.0 (`aws_cognito_user_pool`, `aws_cognito_identity_provider`, `aws_cognito_user_pool_client`, `aws_cognito_user_pool_domain`, `aws_apigatewayv2_authorizer`)

**Storage**:
- User Identity & Profiles: AWS Cognito User Pool (managed user directory)
- Application Data: AWS DynamoDB (`IdeaCollector_Ideas` with `UserIdeasIndex` GSI)

**Testing**:
- Backend: Go unit and contract tests (`go test -v -race ./...`)
- Frontend: TypeScript typechecking (`tsc -b`), linting (`eslint .`), browser E2E scenario validation
- Infra: `terraform validate` and `terraform plan`

**Target Platform**: AWS Serverless (CloudFront, API Gateway HTTP API v2, AWS Cognito User Pool, AWS Lambda on `provided.al2023`, DynamoDB)

**Project Type**: Full-Stack Web Application (Frontend SPA + Serverless Backend + IaC)

**Performance Goals**:
- JIT account provisioning and workspace initialization < 3s (SC-002)
- Returning user sign-in and workspace load < 2s (SC-003)
- Cancelled / failed OAuth handling feedback < 1s (SC-006)
- API response time < 1s

**Constraints**:
- Open public self-registration without invitation code or pre-approval (FR-001)
- Zero internal password storage or credentials committed (Constitution IV, SC-007)
- 100% multi-tenant data isolation; zero cross-user idea exposure (FR-008, SC-004)
- 1-hour session token lifetime with idle re-authentication (FR-013, SC-008)
- Decommission invitation form and endpoints completely (FR-014)

**Scale/Scope**: Production web application on `idea.dinhloc.dev` supporting open public user registration.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **I. AI-Native SDLC Pipeline**: PASS. Feature scope is strictly bounded by `spec.md`. No speculative features added. Verification scenarios and acceptance criteria documented in `quickstart.md`.
- **II. Infrastructure as Code (IaC) & Remote State**: PASS. All AWS resources (Cognito User Pool, Google IdP, User Pool Client, API Gateway JWT Authorizer, DynamoDB tables) are defined via Terraform in `apps/idea-collector/infra/`. Remote S3 + DynamoDB lock state maintained.
- **III. Automated Quality & CI/CD Gates**: PASS. Uses existing GitHub Actions pipelines and Nx targets. Lint, typecheck, and unit tests run before opening a PR.
- **IV. Strict Security & Credential Handling**: PASS. Google Client Secret and ID tokens are passed via Terraform variables / AWS Secrets Manager; zero secrets or credentials committed to the repository. No user passwords stored.
- **V. Codebase Respect & Localization**: PASS. Edits are confined to `apps/idea-collector/` (infra, backend, frontend) and `specs/008-public-registration-google-auth/`. Unrelated monorepo packages remain untouched.
- **Agent Constraints**: PASS. No CI/CD workflow modifications; no manual infrastructure state changes without explicit instruction.

*Post-Design Re-evaluation*: PASS. Phase 0 (`research.md`) and Phase 1 (`data-model.md`, `contracts/`, `quickstart.md`) strictly conform to all constitutional principles.

## Project Structure

### Documentation (this feature)

```text
specs/008-public-registration-google-auth/
├── spec.md              # Feature specification
├── plan.md              # This implementation plan
├── research.md          # Architectural research & technical decisions
├── data-model.md        # Data model & entity schemas
├── quickstart.md        # Verification and validation guide
├── contracts/           # API and OAuth contracts
│   ├── auth-api.yaml    # Cognito OAuth & authentication contract
│   └── ideas-api.yaml   # Ideas API contract with JWT Bearer security
├── checklists/
│   └── requirements.md  # Spec quality checklist
└── tasks.md             # Implementation tasks (/speckit-tasks output)
```

### Source Code (repository root)

```text
apps/idea-collector/
├── infra/                               # Terraform Infrastructure as Code
│   ├── main.tf                          # Cognito User Pool, IdP, Client, API Gateway JWT Authorizer
│   ├── variables.tf                     # Google OAuth credentials, domain variables
│   ├── outputs.tf                       # Cognito User Pool ID, Client ID, domain outputs
│   └── modules/
│       └── frontend/                    # CloudFront + S3 distribution
├── backend/                             # Serverless Go Backend
│   ├── main.go                          # Lambda entry point & routing
│   ├── handlers/
│   │   ├── auth.go                      # GET /api/auth/me (User profile handler)
│   │   ├── ideas.go                     # GET/POST /api/ideas (User-isolated ideas)
│   │   ├── ideas_test.go                # Ideas unit & contract tests
│   │   └── invitations.go               # [DECOMMISSIONED/REMOVED]
│   ├── repository/
│   │   └── dynamo.go                    # DynamoDB interactions for IdeaCollector_Ideas
│   ├── models/
│   │   └── models.go                    # Idea & User data structures
│   └── auth/
│       ├── google.go                    # [REFACTORED/REPLACED BY COGNITO]
│       └── session.go                   # [REFACTORED/REPLACED BY COGNITO JWT]
└── frontend/                            # React 19 + TypeScript SPA
    ├── src/
    │   ├── App.tsx                      # Root component, routing, authenticated workspace state
    │   ├── main.tsx                     # React DOM entry
    │   ├── components/
    │   │   ├── AuthPrompt.tsx           # Prominent "Sign in with Google" button (OAuth PKCE)
    │   │   ├── Header.tsx               # Workspace header with user profile & logout
    │   │   ├── IdeaForm.tsx             # Idea authoring form with draft preservation
    │   │   ├── IdeaList.tsx             # User-isolated idea display & empty state
    │   │   ├── SessionExpiredModal.tsx  # Session timeout & re-authentication prompt
    │   │   └── InviteForm.tsx           # [DECOMMISSIONED/REMOVED]
    │   └── services/
    │       ├── auth.ts                  # Cognito OAuth2 PKCE token exchange & session storage
    │       └── api.ts                   # Fetch wrapper attaching Cognito Bearer token
    └── vite.config.ts                   # Vite configuration
```

**Structure Decision**: Web application utilizing existing `apps/idea-collector/` directory with `infra/` (Terraform AWS Cognito & API Gateway), `backend/` (Go Lambda handlers), and `frontend/` (React 19 SPA). Decommissions invitation components and replaces custom DynamoDB user/session code with Cognito User Pool integration.

## Complexity Tracking

*No constitutional violations; all gates pass.*
