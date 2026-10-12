# Feature Specification: Post-Implementation PR Management Skills

**Feature Branch**: `007-manage-pr-workflow`

**Created**: 2026-10-12

**Status**: Draft

**Input**: User description: "As an github user, I need skills to manage after implementing workflows, for example, create MR, update MR descriptions"

## Clarifications

### Session 2026-10-12

- Q: How should the post-implementation PR management skills be structured and exposed? → A: A unified skill `/speckit-pr` that automatically detects whether to create or update an existing PR, while supporting explicit action flags (`--create`, `--update`, `--status`, `--check`).
- Q: Which mechanism should the skill use to interact with GitHub for PR operations? → A: Dual support: prioritize GitHub CLI (`gh`) when installed and authenticated, with fallback to direct GitHub REST API calls using `GITHUB_TOKEN`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Create Pull Request with Automated Intent & Scope (Priority: P1)

As a developer or AI pairing agent who has finished implementing tasks, I want to execute a dedicated workflow skill that generates and publishes a GitHub Pull Request with a structured description containing clear intent, change scope, affected packages, and verification steps so that my changes can be reviewed without manual copy-pasting.

**Why this priority**: Opening a Pull Request is the foundational bridge between local task completion and the repository's collaborative review and merge pipeline. Without this, no post-implementation automation can proceed.

**Independent Test**: Can be tested on a branch with committed changes by running the PR creation skill. The test passes when a new Pull Request is opened on GitHub containing a title derived from the active feature, a body fulfilling constitutional requirements, and a valid URL returned to the user.

**Acceptance Scenarios**:

1. **Given** a feature branch with committed code changes and an active specification, **When** the developer invokes the PR creation skill, **Then** the system verifies the remote branch is up to date, compiles a structured pull request body (intent, scope, verification steps, affected projects), opens the Pull Request on GitHub, and returns the PR URL.
2. **Given** a user refers to "MR" (Merge Request), **When** invoking the skill, **Then** the system recognizes the command as equivalent to GitHub Pull Request creation and proceeds seamlessly.
3. **Given** a feature branch where no Pull Request currently exists, **When** PR creation is triggered, **Then** the initial PR is created in Draft mode by default, allowing the author to verify the diff and description before opening it for team review (with a flag to publish directly as Ready for Review).

---

### User Story 2 - Synchronize & Update Existing Pull Request Details (Priority: P2)

As a developer or agent continuing work on an active branch, I want to execute a PR update skill that refreshes the existing Pull Request's title, description, completed tasks checklist, and verification notes so that the PR accurately reflects the latest implementation state without clobbering reviewer comments or review threads.

**Why this priority**: Features often require multiple iterations, bug fixes, or feedback cycles. Keeping the PR description synchronized with new commits and task progress ensures transparency throughout the review lifecycle.

**Independent Test**: Can be tested on a branch with an open Pull Request. Making an additional commit and invoking the PR update skill should update the PR description on GitHub while retaining the existing PR number, conversation history, and review state.

**Acceptance Scenarios**:

1. **Given** an active branch with an existing open Pull Request, **When** new commits or task updates are made and the update skill is invoked, **Then** the PR description is updated with refreshed scope, task completion status, and latest verification evidence.
2. **Given** a developer provides custom notes or overrides (e.g., breaking changes summary or reviewer highlights), **When** the update skill executes, **Then** those custom highlights are incorporated into the designated section of the PR description.
3. **Given** a PR description formatted according to the Structured Constitution template (Intent, Scope, Verification Steps, Affected Monorepo Packages, and Quality Checklist), **When** updated, **Then** the existing structure is preserved while updating dynamic sections and task checkboxes.

---

### User Story 3 - Pre-Flight Verification & Quality Gate Validation (Priority: P3)

As a team member adhering to repository governance, I want the post-implementation workflow to execute pre-flight quality checks (linting, typechecking, unit tests, secret leak scans, git branch cleanliness) before publishing or marking a PR ready for review so that broken or non-compliant PRs do not trigger unnecessary CI failures.

**Why this priority**: The monorepo constitution (Principle I & Principle III) mandates that agents must verify compilation, lint, and tests before opening a PR and never commit credentials. Automated pre-flight checks enforce this standard consistently.

**Independent Test**: Can be tested by running the pre-flight check on clean passing code (which succeeds) and on code with intentional lint or test failures (which blocks PR submission and outputs clear failure details).

**Acceptance Scenarios**:

1. **Given** a branch with passing tests and clean git status, **When** pre-flight verification runs, **Then** all quality gates pass and the PR creation/update step is cleared to proceed.
2. **Given** local uncommitted changes exist on the working tree, **When** the PR workflow is invoked, **Then** the system alerts the developer and prompts them to commit or stash uncommitted changes before opening a PR.
3. **Given** quality checks fail (e.g., lint or test errors), **When** pre-flight checks execute, **Then** the workflow halts with a clear error report pinpointing the failed check and prevents PR publication.

---

### User Story 4 - Pull Request Status Inspection & CI Gate Monitoring (Priority: P4)

As a developer awaiting CI/CD outcomes, I want to query the status of an open Pull Request (CI workflow runs, review approvals, mergeability status) through a conversational skill so that I can monitor progress without switching contexts to the browser.

**Why this priority**: Speeds up post-PR feedback loops and allows agents to detect and report whether review or CI interventions are required.

**Independent Test**: Can be tested on an open PR with running or completed GitHub Actions workflows. The skill queries the PR status and outputs a clear summary of checks, approvals, and merge readiness.

**Acceptance Scenarios**:

1. **Given** an open Pull Request with active GitHub Actions checks, **When** the status skill is invoked, **Then** the system reports check statuses (queued, in-progress, passing, failing).
2. **Given** all required status checks have passed and required approvals are met, **When** status is inspected, **Then** the PR is reported as mergeable and ready for final integration.

---

### Edge Cases

- **Uncommitted local changes**: System warns the user and refuses to publish a PR with dirty working tree, preventing omitted changes from surprising reviewers.
- **Remote branch not pushed**: If the local branch has not yet been pushed to the remote repository (`origin`), the workflow automatically pushes the branch with upstream tracking before attempting to create the PR.
- **Duplicate PR creation attempt**: If the developer invokes the create command when a PR already exists for the branch, the system detects the existing PR and transparently falls back to updating the PR rather than failing with an error.
- **Base branch divergence**: If the target base branch is not `main` (e.g., a release branch or integration branch), the workflow allows overriding the base branch.
- **Missing GitHub credentials / authentication**: If GitHub authentication is missing or expired, the system provides a clear diagnostic message with actionable remediation steps (e.g., running `gh auth login` or setting `GITHUB_TOKEN`).
- **Large multi-package diffs**: If changes span multiple monorepo applications or shared packages, the summary automatically groups changes by affected workspace projects.

---

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a unified skill `/speckit-pr` that automatically detects whether to create or update a Pull Request, while supporting explicit action flags (`--create`, `--update`, `--status`, `--check`).
- **FR-002**: System MUST automatically generate PR titles and structured bodies incorporating Intent, Scope, Verification Steps, Affected Projects, and Spec/Issue links in compliance with project governance.
- **FR-003**: System MUST support updating the title, body description, and task checklist of an existing open Pull Request on GitHub without affecting existing reviewer comments or discussion threads.
- **FR-004**: System MUST accept alternative aliases for Pull Request operations (e.g., "MR", "Merge Request", "create-mr", "update-mr") and map them to GitHub Pull Request actions.
- **FR-005**: System MUST perform pre-flight validation (git cleanliness, linting, test suites, and credential absence) before opening or updating a Pull Request.
- **FR-006**: System MUST handle remote branch synchronization, ensuring local commits are pushed to the remote upstream repository before opening a Pull Request.
- **FR-007**: System MUST detect when a Pull Request already exists for the current branch and switch to updating the existing PR instead of generating duplicate PRs.
- **FR-008**: System MUST provide status inspection capabilities to report CI check run outcomes, approval states, and merge readiness for the current PR.
- **FR-009**: System MUST publish Pull Requests in Draft mode by default to enable review before requesting team feedback, while supporting a flag to publish directly as Ready for Review.
- **FR-010**: System MUST structure the generated Pull Request description using the Structured Constitution format, comprising Intent, Scope, Verification Steps, Affected Monorepo Packages, and a Quality Checklist.
- **FR-011**: System MUST support dual GitHub communication channels, prioritizing the GitHub CLI (`gh`) when available and authenticated, and falling back to direct GitHub REST API operations using `GITHUB_TOKEN` for headless or container environments.
- **FR-012**: System MUST integrate the new `/speckit-pr` skill into the repository's onboarding suite by registering it in `scripts/lib/skills-audit.sh`, updating `.agents/skills/dev-onboarding/SKILL.md` to audit and report it, and documenting it in `docs/ONBOARDING.md`.

### Key Entities *(include if feature involves data)*

- **PullRequest**: Represents the GitHub Pull Request resource; key attributes include PR number, title, body markdown, state (draft, open, merged, closed), head branch, base branch, web URL, author, and review status.
- **ChangeSummary**: Captures the synthesized scope of changes; includes list of commits, modified files, affected monorepo projects, completed task items from `tasks.md`, and references to active specifications.
- **QualityGateResult**: Encapsulates pre-flight verification outcomes; includes lint check status, test suite run status, typecheck status, git clean status, and secret detection result.
- **CheckRunStatus**: Represents CI/CD execution status on GitHub; includes workflow name, job status (queued, in_progress, completed), and conclusion (success, failure, neutral).

---

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Developers and agents can generate and open a fully formatted Pull Request in under 30 seconds after completing implementation.
- **SC-002**: 100% of generated Pull Requests contain explicit Intent, Scope, and Verification Steps as required by repository governance.
- **SC-003**: Updating an existing Pull Request preserves 100% of existing review comments, comment threads, and reviewer assignments.
- **SC-004**: Pre-flight verification catches and blocks 100% of uncommitted working tree anomalies and failing local test gates prior to remote PR publishing.
- **SC-005**: 95% of users can complete end-to-end post-implementation workflows (check, open PR, update description) using only conversational slash command skills without manual browser navigation.

---

## Assumptions

- Users have authenticated access to GitHub via either the GitHub CLI (`gh`) or a `GITHUB_TOKEN` environment variable.
- The primary git remote is named `origin` and tracks the central GitHub repository.
- Default base branch for pull requests is `main`, with configurable overrides when targeting release branches.
- Monorepo package boundaries correspond to directories under `apps/`, `infra/`, and `packages/` or `shared/`.
- Post-implementation skills are invoked either manually by developers or autonomously by paired AI agents following `/speckit-implement` or `/speckit-converge`.
