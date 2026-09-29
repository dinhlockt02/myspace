# Implementation Plan: Complete Idea Collector Infrastructure

**Branch**: `001-complete-idea-collector-infra` | **Date**: 2026-09-28 | **Spec**: [specs/001-complete-idea-collector-infra/spec.md](file:///home/loctran/code/myspace/specs/001-complete-idea-collector-infra/spec.md)

**Input**: Feature specification from `/specs/001-complete-idea-collector-infra/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Complete the full-stack infrastructure for the idea collector application under the unified domain `idea.dinhloc.dev`. This includes deploying the React frontend to an S3 bucket served by CloudFront, and provisioning an API Gateway HTTP API, Lambda function, and DynamoDB table for backend ingestion. CloudFront will route `/api/*` traffic to the API Gateway to prevent CORS issues.

## Technical Context

**Language/Version**: Terraform 1.9.0+, Go (Lambda), TypeScript/React (Frontend)

**Primary Dependencies**: AWS Provider ~> 5.0, Nx

**Storage**: AWS DynamoDB (for ideas), AWS S3 (for static assets)

**Testing**: Terraform validate/fmt/plan

**Target Platform**: AWS (CloudFront, S3, API Gateway, Lambda, DynamoDB)

**Project Type**: Infrastructure / Serverless Application

**Performance Goals**: < 1.5s page load, < 1.0s API response

**Constraints**: Fully automated deployments (no manual console changes), AWS services only

**Scale/Scope**: idea.dinhloc.dev portal and ingestion backend

## Constitution Check
 
*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- **Multi-language monorepo**: Checked. Apps are in `apps/idea-collector`.
- **Infrastructure as code**: Checked. All resources managed via Terraform in `apps/idea-collector/infra/`.
- **CI/CD**: Checked. GitHub Actions will handle deployment.
- **Agent constraints**: Checked. No secrets committed, no manual infra changes, existing code style followed.

## Project Structure

### Documentation (this feature)

```text
specs/001-complete-idea-collector-infra/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output
```

### Source Code (repository root)

```text
apps/
└── idea-collector/
    ├── frontend/        # React application (existing)
    │   ├── src/
    │   └── project.json # Nx configuration for build and deploy
    ├── backend/         # Go Lambda function for ingestion (to be recreated)
    │   ├── main.go
    │   ├── go.mod
    │   └── Makefile
    └── infra/           # Terraform configuration (existing, to be expanded)
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

**Structure Decision**: Monorepo structure with separated `frontend/`, `backend/`, and `infra/` directories for the `idea-collector` application. This aligns with the AGENTS.md monorepo rules.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

*(No violations found)*
