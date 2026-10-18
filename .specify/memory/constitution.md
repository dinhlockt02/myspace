# Myspace Monorepo Constitution

## Core Principles

### I. AI-Native SDLC Pipeline
Agents MUST manage the end-to-end lifecycle including code authoring, PR creation, reviews, and deployments. Humans set direction and approve only when dictated by policy. Every PR MUST include a clear intent, scope, and verification steps. Speculative changes are strictly prohibited—only implement what the task explicitly requires.

### II. Infrastructure as Code (IaC) & Remote State
All infrastructure MUST be defined via Terraform (for AWS resources) or Kubernetes manifests/Helm charts (in `infra/k8s/` or per-service `deploy/`). No manual console changes are allowed. State MUST be managed remotely (e.g., S3 + DynamoDB). Changes to `infra/` require explicit human approval before merging.

### III. Automated Quality & CI/CD Gates
All pipelines MUST run on GitHub Actions. Each service or package MUST have its own workflow or matrix entry. Agents MUST run lint, typecheck, and tests before opening a PR. Merges to `main` or tag pushes trigger deployments. New services MUST include corresponding CI workflows.

### IV. Strict Security & Credential Handling
Under no circumstances may secrets, credentials, or sensitive data be committed to the repository. Agents MUST strictly adhere to this rule during all operations.

### V. Codebase Respect & Localization
Agents MUST follow the existing code style in each project and MUST NOT reformat unrelated code. Scope creep is not allowed; changes should be strictly limited to the task at hand.

### VI. Branch Discipline & Naming
Code changes MUST NOT be made or committed on `main` or `master`. Before changing anything, agents MUST ask the user for a branch name and create it. Branch names MUST be `<type>/<description>` or `<type>/<scope>/<description>`, where type is one of `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `ci`, `infra`, `req` and scope is optional; Spec Kit branches MAY use `NNN-<description>`. Descriptions and scopes MUST be lowercase kebab-case, and descriptions MUST be 3-50 characters. `main`, `master`, `develop`, `HEAD` and `release/*` are reserved. This is enforced by the PreToolUse hook `.claude/hooks/require_feature_branch.py` (rules in `.claude/hooks/branch_policy.py`) and by the Spec Kit skills. Rationale: every change is reviewed through a PR, and consistent names make the monorepo history and CI scoping legible.

## Repository Structure

- **Infrastructure**: `infra/` (Terraform, AWS, Kubernetes manifests)
- **Shared code**: `packages/` or `shared/` (Shared libraries, configs, and tooling)
- **CI/CD**: `.github/workflows/` (GitHub Actions pipelines)
- **Projects**: Multi-language monorepo where each project lives under its own top-level directory

## Agent Constraints

- Agents MUST NOT modify CI/CD workflows without explicit instruction.
- Agents MUST NOT change infrastructure state without explicit instruction.
- Agents MUST NOT code on `main`/`master`; they MUST ask for a branch name that satisfies Principle VI.
- Agents MUST ensure that all code compiles, type-checks, and passes tests before a PR is opened.

## Governance

This Constitution acts as the source of truth for the Myspace Monorepo development lifecycle. It supersedes all other informal practices. 

- All pull requests and automated agent actions MUST comply with the rules outlined in this document. 
- Amendments to this constitution require a clear rationale, incrementing the semantic version, and an update to the Last Amended date.
- Code reviewers (human or agent) MUST use these principles as the basis for evaluating PRs.

**Version**: 1.1.0 | **Ratified**: 2026-09-29 | **Last Amended**: 2026-10-18
