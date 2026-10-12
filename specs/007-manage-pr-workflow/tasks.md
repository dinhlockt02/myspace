# Tasks: Post-Implementation PR Management Skills

**Feature**: `007-manage-pr-workflow`
**Input**: [spec.md](spec.md), [plan.md](plan.md), [data-model.md](data-model.md), [contracts/](contracts/), [research.md](research.md), [quickstart.md](quickstart.md)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [X] T001 Initialize CLI script skeleton with flag parsing in `scripts/pr-workflow.sh`
- [X] T002 [P] Wire `pnpm run pr` command in `package.json`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T003 Implement git working tree and branch helpers in `scripts/lib/pr-git.sh`
- [X] T004 [P] Implement dual GitHub communication client (`gh` CLI + REST API fallback) in `scripts/lib/pr-client.sh`
- [X] T005 [P] Implement spec and monorepo diff parser in `scripts/lib/pr-formatter.sh`

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Create Pull Request with Automated Intent & Scope (Priority: P1) 🎯 MVP

**Goal**: Enable developers and pairing agents to generate and open a GitHub Pull Request (defaulting to Draft mode) with automated intent, scope, and verification steps.

**Independent Test**: Execute `bash scripts/pr-workflow.sh create --draft --json` on a clean feature branch. Passes if branch is pushed, a Draft PR is opened on GitHub, and a valid PR URL with structured markdown body is returned.

### Implementation for User Story 1

- [X] T006 [US1] Implement PR title and constitutional body synthesis adhering to Principle I in `scripts/lib/pr-formatter.sh`
- [X] T007 [US1] Implement `create` command with `--draft` default and `--ready` flag in `scripts/pr-workflow.sh`
- [X] T008 [P] [US1] Create companion AI agent skill manifest and instructions in `.agents/skills/speckit-pr/SKILL.md`
- [X] T009 [US1] Validate Scenario 3 (draft creation) and Scenario 6 (`/speckit-pr`) per `specs/007-manage-pr-workflow/quickstart.md`

**Checkpoint**: At this point, User Story 1 delivers an end-to-end viable MVP for creating Pull Requests.

---

## Phase 4: User Story 2 - Synchronize & Update Existing Pull Request Details (Priority: P2)

**Goal**: Enable refreshing an existing Pull Request's title, description, and task checklist without clobbering reviewer comments or conversation threads.

**Independent Test**: Push an additional commit to an active branch and execute `bash scripts/pr-workflow.sh update --json`. Passes if PR description and tasks are updated on GitHub while retaining existing PR number and review threads.

### Implementation for User Story 2

- [X] T010 [US2] Implement body update and comment preservation logic (`<!-- custom-notes -->`) in `scripts/lib/pr-formatter.sh`
- [X] T011 [US2] Implement `update` command and auto-detect branch PR logic in `scripts/pr-workflow.sh`
- [X] T012 [P] [US2] Add update flow and notes flag handling to `.agents/skills/speckit-pr/SKILL.md`
- [X] T013 [US2] Validate Scenario 4 (PR update and synchronization) per `specs/007-manage-pr-workflow/quickstart.md`

**Checkpoint**: User Stories 1 AND 2 work independently, supporting the complete PR authoring and synchronization loop.

---

## Phase 5: User Story 3 - Pre-Flight Verification & Quality Gate Validation (Priority: P3)

**Goal**: Block PR submission locally if git working tree is dirty, lint/test suites fail on affected packages, or sensitive credentials are found in diffs.

**Independent Test**: Execute `bash scripts/pr-workflow.sh check`. Passes cleanly on clean passing code, and halts with error code 1 when uncommitted changes or lint errors exist.

### Implementation for User Story 3

- [X] T014 [US3] Implement git cleanliness check and secret leak scanning in `scripts/lib/pr-gates.sh`
- [X] T015 [P] [US3] Implement Nx and Go quality test runner in `scripts/lib/pr-gates.sh`
- [X] T016 [US3] Wire pre-flight gate enforcement into `check`, `create`, and `update` commands in `scripts/pr-workflow.sh`
- [X] T017 [US3] Validate Scenario 1 (clean pass) and Scenario 2 (dirty working tree blocked) per `specs/007-manage-pr-workflow/quickstart.md`

**Checkpoint**: Quality gates strictly guard remote PR operations, enforcing Monorepo Constitution Principles I, III, and IV.

---

## Phase 6: User Story 4 - Pull Request Status Inspection & CI Gate Monitoring (Priority: P4)

**Goal**: Query GitHub Actions CI check run statuses, review approvals, and merge readiness directly from the command line and conversational agent skill.

**Independent Test**: Execute `bash scripts/pr-workflow.sh status --json` on a branch with an open PR. Passes if active/completed GitHub Actions runs and mergeability status are reported.

### Implementation for User Story 4

- [X] T018 [US4] Implement GitHub Actions CI check query and merge readiness parser in `scripts/lib/pr-client.sh`
- [X] T019 [US4] Implement `status` command in `scripts/pr-workflow.sh`
- [X] T020 [P] [US4] Add status inspection command flow to `.agents/skills/speckit-pr/SKILL.md`
- [X] T021 [US4] Validate Scenario 5 (PR checks and status inspection) per `specs/007-manage-pr-workflow/quickstart.md`

**Checkpoint**: All 4 user stories are fully implemented and verifiable.

---

## Phase 7: Onboarding Suite Integration & Documentation

**Purpose**: Register `/speckit-pr` into the repository onboarding system, skills health audit, and documentation.

- [X] T022 [P] Register `speckit-pr` in `expected_skills` in `scripts/lib/skills-audit.sh`
- [X] T023 [P] Update Phase 3 AI skills audit count and reporting in `.agents/skills/dev-onboarding/SKILL.md`
- [X] T024 [P] Document `/speckit-pr` in repository developer guide in `docs/ONBOARDING.md`
- [X] T025 Validate Scenario 7 (skills audit reports 11 operational skills) per `specs/007-manage-pr-workflow/quickstart.md`

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Final permissions, executable validation, and end-to-end smoke testing

- [X] T026 [P] Ensure executable permissions (`chmod +x`) on `scripts/pr-workflow.sh`
- [X] T027 Run full end-to-end smoke test suite verification across all quickstart scenarios in `specs/007-manage-pr-workflow/quickstart.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Can start immediately.
- **Foundational (Phase 2)**: Depends on Setup (Phase 1) — **BLOCKS all user stories**.
- **User Story 1 (Phase 3)**: Depends on Foundational (Phase 2). Delivers core MVP.
- **User Story 2 (Phase 4)**: Depends on User Story 1 (Phase 3).
- **User Story 3 (Phase 5)**: Can start after Foundational (Phase 2); integrates with US1 and US2 commands.
- **User Story 4 (Phase 6)**: Depends on Foundational (Phase 2).
- **Onboarding Integration (Phase 7)**: Depends on User Story 1 (requires `speckit-pr/SKILL.md` to exist for audit).
- **Polish (Phase 8)**: Depends on all prior phases being complete.

---

## Parallel Opportunities

- **Phase 1**: `T002` [P] in parallel with `T001`.
- **Phase 2**: `T004` [P] and `T005` [P] in parallel with `T003`.
- **Phase 3**: `T008` [P] in parallel with `T006`/`T007`.
- **Phase 4**: `T012` [P] in parallel with `T010`/`T011`.
- **Phase 5**: `T015` [P] in parallel with `T014`.
- **Phase 6**: `T020` [P] in parallel with `T018`/`T019`.
- **Phase 7**: `T022` [P], `T023` [P], `T024` [P] can run concurrently.
- **Phase 8**: `T026` [P] in parallel with final verification preparation.

---

## Implementation Strategy

### MVP Scope (Phase 1 through Phase 3)
Complete Phase 1 (Setup), Phase 2 (Foundational), and Phase 3 (User Story 1). At this checkpoint, developers can run `/speckit-pr` to automatically push code and create Draft Pull Requests with full constitutional descriptions.

### Incremental Delivery
1. **Increment 1**: MVP PR Creation (`create`, `/speckit-pr`).
2. **Increment 2**: PR Synchronization & Updates (`update`).
3. **Increment 3**: Pre-Flight Gate Validation (`check`, git/lint/test/secrets enforcement).
4. **Increment 4**: Status Inspection (`status`, CI/CD checks query).
5. **Increment 5**: Onboarding Suite Registration (`skills-audit.sh`, `dev-onboarding`, `ONBOARDING.md`).
