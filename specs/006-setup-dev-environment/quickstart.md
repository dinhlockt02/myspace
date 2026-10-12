# Quickstart: Validation Guide for Developer Environment Onboarding

This guide outlines how to validate the developer onboarding workflow, local backing containers, and AI skills health checks end-to-end.

## Prerequisites

- Local workstation running Linux, macOS, or Windows WSL with terminal access.
- Git repository clone at `myspace`.
- Docker engine and Docker Compose installed and running.

---

## Scenario 1: Validate Prerequisite Assessment (Non-Destructive)

Prove that the prerequisite check correctly scans the host environment without altering files or installing packages.

1. **Run the prerequisite diagnostic command:**
   ```bash
   pnpm run setup -- --check-only
   ```
   *(Or alternatively: `./scripts/setup-dev.sh --check-only`)*

2. **Expected Outcome:**
   - The tool audits Node.js, pnpm, Go, Docker engine, and Docker Compose versions.
   - If all tools are present and compatible, a green summary is displayed with individual tool versions.
   - If any tool is missing or outdated, exact remediation commands and links are output.
   - Exit code: `0` if all prerequisites pass; `1` if any prerequisite is missing.

3. **Verify Machine-Readable Mode:**
   ```bash
   ./scripts/setup-dev.sh --check-only --json
   ```
   *Expected Output*: Valid JSON payload matching [`contracts/report-schema.json`](contracts/report-schema.json).

---

## Scenario 2: Validate Automated Workspace Bootstrap & Environment Templates

Prove that dependencies are installed and `.env` configuration files are populated with safe local defaults.

1. **Execute the workspace bootstrap:**
   ```bash
   pnpm run setup -- --bootstrap
   ```

2. **Verify Environment Configurations:**
   Inspect the generated configuration files:
   ```bash
   test -f apps/idea-collector/frontend/.env && echo "Frontend .env exists"
   test -f apps/idea-collector/backend/.env && echo "Backend .env exists"
   ```
   *Expected Output*: Both files exist and contain local mock/container endpoints (`VITE_API_URL=http://localhost:8080`, `DYNAMODB_ENDPOINT=http://localhost:8000`), with zero real secrets.

3. **Verify Idempotency:**
   Run the bootstrap command again:
   ```bash
   pnpm run setup -- --bootstrap
   ```
   *Expected Output*: Completes quickly without overwriting existing files or corrupting state.

---

## Scenario 3: Validate Local Containerized Backing Services (DynamoDB Local)

Prove that local backing service containers are started and healthy.

1. **Launch backing service containers:**
   ```bash
   pnpm run setup -- --containers
   ```

2. **Verify Container Health:**
   ```bash
   docker compose ps
   curl -s http://localhost:8000/shell/ || curl -I http://localhost:8000
   ```
   *Expected Output*:
   - `dynamodb-local` container is in `healthy` or `running` state.
   - Port 8000 responds to HTTP requests.

---

## Scenario 4: Validate AI-Native SDLC Skills Health Audit

Prove that all repository AI skills, rules, and governance files are verified.

1. **Run the AI skill diagnostic check:**
   ```bash
   ./scripts/setup-dev.sh --verify-skills
   ```
   *(Or trigger the `/dev-onboarding` skill inside your AI agent session)*

2. **Expected Output:**
   - Audits all 10 Spec-Kit skills in `.agents/skills/` (`speckit-specify`, `speckit-clarify`, `speckit-plan`, `speckit-tasks`, `speckit-implement`, `speckit-converge`, `speckit-analyze`, `speckit-checklist`, `speckit-taskstoissues`, `speckit-constitution`).
   - Verifies `AGENTS.md` and `.specify/memory/constitution.md` presence and readability.
   - Reports `100% operational` status across the complete SDLC suite.

---

## Scenario 5: Validate End-to-End Smoke Test and Diagnostic Persistence

Prove that the entire monorepo builds, lints, and tests against local services, and persists the diagnostic report.

1. **Run full verification smoke test:**
   ```bash
   pnpm run setup -- --verify
   ```

2. **Verify Diagnostic Artifact:**
   ```bash
   ls -la .specify/reports/
   cat .specify/reports/latest-onboarding.md
   ```
   *Expected Output*:
   - Smoke test executes Nx builds and tests across `apps/idea-collector` and other workspace projects.
   - A timestamped JSON report is saved in `.specify/reports/onboarding-<timestamp>.json`.
   - `latest-onboarding.md` contains the formatted summary showing passing status for all components.
   - Total execution finishes in under 5 minutes.
