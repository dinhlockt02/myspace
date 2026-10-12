# Tasks: Developer Environment Onboarding and AI Skills Setup

**Input**: Design documents from `/specs/006-setup-dev-environment/`
**Prerequisites**: [`plan.md`](plan.md), [`spec.md`](spec.md), [`research.md`](research.md), [`data-model.md`](data-model.md), [`contracts/`](contracts/), [`quickstart.md`](quickstart.md)

**Tests**: Testing is implemented natively via execution of diagnostic checks, automated smoke tests across monorepo projects, and the runnable scenarios in `quickstart.md`.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `- [ ] [TaskID] [P?] [Story?] Description with file path`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4, US5)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Repository initialization, ignore rules, and report directory structures

- [x] T001 Configure `.gitignore` to ensure `.specify/reports/` and local `.env` files are ignored across all projects
- [x] T002 Add `setup` command script entry point to `package.json` (`"setup": "bash scripts/setup-dev.sh"`)
- [x] T003 [P] Create `scripts/lib/reporter.sh` supporting ANSI color formatting, console summaries, and directory creation for `.specify/reports/`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure, CLI command dispatcher, and container definitions that MUST be complete before user story implementation

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T004 Create core CLI entry point `scripts/setup-dev.sh` with argument parsing for flags `--check-only`, `--bootstrap`, `--containers`, `--verify-skills`, `--verify`, `--clean`, `--json`, and `--help` per `contracts/cli-schema.yml`
- [x] T005 [P] Create root `docker-compose.yml` declaring `dynamodb-local` service (`amazon/dynamodb-local:latest`) mapped to port `8000:8000` with data volume and healthcheck probe
- [x] T006 [P] Create `scripts/lib/containers.sh` providing Docker daemon responsiveness checks, container startup (`docker compose up -d`), health status polling, and shutdown functions

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Interactive Environment Assessment and Prerequisites Verification (Priority: P1) 🎯 MVP

**Goal**: Deliver host workstation assessment auditing Node.js, pnpm, Go, Docker engine, and Docker Compose versions with actionable remediation instructions for missing or outdated tools.

**Independent Test**: Execute `./scripts/setup-dev.sh --check-only` (or `pnpm run setup -- --check-only`) and verify that host tool versions are correctly detected, missing/incompatible items output remediation links, and `--json` outputs a valid profile payload.

### Implementation for User Story 1

- [x] T007 [P] [US1] Create `scripts/lib/prerequisites.sh` implementing minimum version checks for Node.js (>= 20.0.0), pnpm (>= 9.0.0), Go (>= 1.22.0), Docker Engine (>= 24.0.0), and Docker Compose (>= 2.20.0)
- [x] T008 [US1] Implement OS detection (`linux`, `darwin`, `windows_wsl`) and platform-specific remediation guidance (install links and commands) in `scripts/lib/prerequisites.sh`
- [x] T009 [US1] Wire prerequisite evaluation and `Developer Environment Profile` JSON serialization into `scripts/setup-dev.sh --check-only`

**Checkpoint**: At this point, User Story 1 is fully functional and testable independently.

---

## Phase 4: User Story 2 - Automated Workspace Bootstrapping and Dependency Initialization (Priority: P1)

**Goal**: Automatically install monorepo dependencies across pnpm and Go workspaces, launch local backing containers, and instantiate local `.env` configuration files from `.env.example` templates with safe local defaults.

**Independent Test**: Execute `./scripts/setup-dev.sh --bootstrap --containers`, verify that `pnpm install` succeeds, `dynamodb-local` container is running and healthy on port 8000, and `.env` files are generated in `apps/idea-collector/frontend/` and `apps/idea-collector/backend/` with working mock values.

### Implementation for User Story 2

- [x] T010 [P] [US2] Create `apps/idea-collector/frontend/.env.example` with local development defaults (`VITE_API_URL=http://localhost:8080`, `VITE_STAGE=local`)
- [x] T011 [P] [US2] Create `apps/idea-collector/backend/.env.example` with local container defaults (`PORT=8080`, `DYNAMODB_ENDPOINT=http://localhost:8000`, `AWS_REGION=us-east-1`, `TABLE_NAME=IdeaCollector_Ideas_local`, dummy credentials)
- [x] T012 [US2] Create `scripts/lib/templates.sh` implementing idempotent template copying (`.env.example` to `.env` without overwriting existing files)
- [x] T013 [US2] Implement dependency installation logic in `scripts/setup-dev.sh` to execute `pnpm install` at root and `go mod download` in `apps/idea-collector/backend/`
- [x] T014 [US2] Wire container provisioning and template generation into `scripts/setup-dev.sh --bootstrap --containers`

**Checkpoint**: At this point, User Stories 1 AND 2 work independently.

---

## Phase 5: User Story 3 - AI Skills Discovery, Health Check, and Capabilities Verification (Priority: P2)

**Goal**: Audit and verify that all 10 Spec-Kit skills, git commit standardization rules, and repository constitutional governance documents are discoverable, readable, and operational.

**Independent Test**: Run `./scripts/setup-dev.sh --verify-skills` and verify that all skills in `.agents/skills/` and constitutional documents in `.specify/memory/` and `AGENTS.md` are audited and reported as operational.

### Implementation for User Story 3

- [x] T015 [P] [US3] Create `scripts/lib/skills-audit.sh` scanning `.agents/skills/` to validate all 10 Spec-Kit skills and checking `AGENTS.md` and `.specify/memory/constitution.md`
- [x] T016 [US3] Wire skills audit evaluation into `scripts/setup-dev.sh --verify-skills` and serialize results matching `Skill Verification Record` schema
- [x] T017 [US3] Create companion AI onboarding skill `.agents/skills/dev-onboarding/SKILL.md` implementing the `/dev-onboarding` command protocol per `contracts/skill-contract.md`

**Checkpoint**: At this point, User Stories 1, 2, and 3 work independently.

---

## Phase 6: User Story 4 - End-to-End Workspace Smoke Test and Health Diagnostic (Priority: P2)

**Goal**: Execute an end-to-end non-destructive smoke test across all monorepo projects (lint, typecheck, build, test) against local container services and persist diagnostic reports to `.specify/reports/`.

**Independent Test**: Execute `./scripts/setup-dev.sh --verify`, confirm all Nx project checks pass in under 5 minutes, and verify that `.specify/reports/latest-onboarding.md` and `.specify/reports/onboarding-<timestamp>.json` are generated.

### Implementation for User Story 4

- [x] T018 [US4] Implement smoke test execution in `scripts/setup-dev.sh --verify` running `pnpm nx run-many -t lint,test,build` and Go test passes against running local backing containers
- [x] T019 [US4] Implement report serialization in `scripts/lib/reporter.sh` saving `.specify/reports/onboarding-<timestamp>.json` (matching `contracts/report-schema.json`) and `.specify/reports/latest-onboarding.md`
- [x] T020 [US4] Implement `--clean` flag in `scripts/setup-dev.sh` to optionally purge node_modules, build caches, and stale Docker container state before test runs

**Checkpoint**: At this point, User Stories 1 through 4 are fully functional and verifiable.

---

## Phase 7: User Story 5 - Developer Onboarding Guide and Self-Service Troubleshooting (Priority: P3)

**Goal**: Provide centralized developer onboarding documentation, workflow cheat-sheets, container lifecycle commands, and solutions for common onboarding friction points.

**Independent Test**: Inspect `docs/ONBOARDING.md`, run the documented quick-start commands, and verify that all links and instructions match actual workspace behaviors.

### Implementation for User Story 5

- [x] T021 [P] [US5] Create centralized onboarding documentation in `docs/ONBOARDING.md` covering prerequisites, setup commands, container lifecycle, and AI skills cheat-sheet
- [x] T022 [US5] Add self-service troubleshooting section to `docs/ONBOARDING.md` covering Docker daemon errors, port 8000 collisions, permission barriers, and stale dependency caches

**Checkpoint**: All user stories are now independently functional and documented.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Final validations, permissions checks, and execution of end-to-end quickstart scenarios

- [x] T023 [P] Ensure executable permissions (`chmod +x`) on `scripts/setup-dev.sh` and all scripts in `scripts/lib/` and verify `--help` output
- [x] T024 Execute all 5 validation scenarios defined in `specs/006-setup-dev-environment/quickstart.md` to confirm end-to-end readiness

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Phase 2
- **User Story 2 (Phase 4)**: Depends on Phase 2 and US1
- **User Story 3 (Phase 5)**: Depends on Phase 2
- **User Story 4 (Phase 6)**: Depends on Phase 2, US1, and US2 (requires containers running)
- **User Story 5 (Phase 7)**: Depends on US1-US4 completion
- **Polish (Phase 8)**: Depends on all user stories being complete

### User Story Dependencies

```
[ Phase 1: Setup ]
        │
        ▼
[ Phase 2: Foundational ]
        │
        ├──────────────────────┬──────────────────────┐
        ▼                      ▼                      ▼
[ Phase 3: US1 (Prereqs) ]     │             [ Phase 5: US3 (AI Skills) ]
        │                      │                      │
        ▼                      │                      │
[ Phase 4: US2 (Bootstrap) ] ◄─┘                      │
        │                                             │
        ▼                                             │
[ Phase 6: US4 (Smoke Test) ] ◄───────────────────────┘
        │
        ▼
[ Phase 7: US5 (Onboarding Guide) ]
        │
        ▼
[ Phase 8: Polish & Validation ]
```

---

## Parallel Execution Opportunities

- **Phase 1**: `T003` can run in parallel with `T001` and `T002`.
- **Phase 2**: `T005` (docker-compose) and `T006` (containers.sh) can run in parallel.
- **Phase 4**: `T010` (frontend .env.example) and `T011` (backend .env.example) can run in parallel.
- **Phase 5 & Phase 6**: Once Phase 2 and US2 are complete, `US3` (AI Skills Audit) and `US4` (Smoke Test) can proceed independently.
- **Phase 7 & Phase 8**: `T021` (docs) and `T023` (permissions) can run in parallel.

---

## Implementation Strategy

### MVP First (User Story 1 + Prerequisite Checks)

1. Complete Phase 1: Setup (ignore rules, package.json entry, reporter)
2. Complete Phase 2: Foundational (CLI dispatcher, docker-compose, containers helper)
3. Complete Phase 3: User Story 1 (Prerequisite assessment)
4. **Validate MVP**: Run `./scripts/setup-dev.sh --check-only` and verify host compatibility checks pass.

### Incremental Delivery

1. Deliver US1 (Prerequisites) -> Immediate value: detects missing host tools.
2. Deliver US2 (Bootstrap + Containers) -> Automated setup and local DynamoDB Local running.
3. Deliver US3 (AI Skills Audit) -> Verifies agent pairing environment.
4. Deliver US4 (Smoke Test & Reporting) -> End-to-end verification and persistent reports.
5. Deliver US5 (Onboarding Guide) -> Self-service documentation and troubleshooting.
