# Feature Specification: Standardize Commits Skill

**Feature Branch**: `003-standardize-commits`

**Created**: 2026-10-11

**Status**: Draft

**Input**: User description: "For this repo, I need a skill for standardize commits."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Structured Commit Message Generation for Staged Changes (Priority: P1)

A repository contributor (developer or automated agent) finishes staging modifications for a task and invokes the standardized commit workflow. The system inspects the staged modifications, determines the appropriate change category (such as a new feature, bug fix, maintenance chore, documentation update, or refactor) and the affected monorepo scope (such as an application, shared package, infrastructure component, or CI workflow), and constructs a clear, compliant commit message following Conventional Commits standards.

**Why this priority**: Consistent, structured commit messages are the foundation of clean version history, automated semantic release management, and auditable change logs across the monorepo.

**Independent Test**: Can be tested independently by staging modifications in any workspace component, triggering the standardization workflow, and verifying that the generated commit message strictly matches the expected format, correct change category, and accurate component scope.

**Acceptance Scenarios**:

1. **Given** staged modifications affecting a specific monorepo application or package, **When** the commit standardization is executed, **Then** the system produces a commit message identifying the affected component as the scope and using the appropriate change category (e.g., `type(scope): imperative summary`).
2. **Given** staged modifications affecting repository-wide configurations, automation workflows, or root files, **When** the commit standardization is executed, **Then** the system assigns the appropriate overarching scope (e.g., `infra`, `ci`, or general chore).
3. **Given** no files or modifications are staged in the workspace, **When** commit standardization is invoked, **Then** the system halts cleanly and notifies the contributor that no changes are staged, providing instructions on staging changes before committing.

---

### User Story 2 - Review, Customization, and Safe Commit Execution (Priority: P1)

Before any commit is permanently recorded in the version control history, the contributor is presented with the proposed commit message for review. The contributor can accept the message as-is, supply adjustments to refine intent or wording, or cancel the operation safely without altering staged files.

**Why this priority**: Human and agent oversight ensures that changes are accurately described before becoming part of permanent repository history, preventing accidental or erroneous commits.

**Independent Test**: Can be tested independently by generating a proposal, exercising both direct approval and adjustment flows, and verifying that approved messages are committed cleanly to the git log while cancelled operations leave the staging area unchanged.

**Acceptance Scenarios**:

1. **Given** a generated commit proposal, **When** the contributor confirms the proposal, **Then** the system commits the staged changes with the exact approved message and displays the resulting commit reference.
2. **Given** a generated commit proposal, **When** the contributor provides adjustments or refinements to the summary or description, **Then** the system updates the message accordingly and requests final confirmation before committing.
3. **Given** a generated commit proposal, **When** the contributor cancels the operation, **Then** no commit is recorded and all staged files remain staged and intact.

---

### User Story 3 - Handling Breaking Changes and Multi-Component Impact (Priority: P2)

When a modification introduces breaking changes (such as breaking schema changes or altered public interfaces) or spans multiple related components, the workflow prompts for or identifies the breaking impact, formats standard breaking change notices and footers, and warns the contributor if changes are overly broad or should be split into smaller atomic commits.

**Why this priority**: Breaking changes require prominent visibility in version control to ensure downstream releases bump versions appropriately. Flagging mixed unrelated changes reinforces atomic commit discipline.

**Independent Test**: Can be tested independently by staging changes with breaking implications, verifying that breaking change indicators and explanatory footers are included, and verifying that staging unrelated distinct projects triggers a recommendation to split commits.

**Acceptance Scenarios**:

1. **Given** staged changes that introduce a breaking modification, **When** the commit is processed, **Then** the system formats the commit header with a breaking change indicator and includes a detailed breaking change explanation in the message footer.
2. **Given** staged changes spanning multiple unrelated projects, **When** the commit standardization analyzes the diff, **Then** the system cautions the contributor about combining unrelated scopes and offers recommendations to isolate each component into an atomic commit.

---

### User Story 4 - Commit Message Linting and Format Validation (Priority: P3)

When a contributor inputs a custom commit message or edits a draft manually, the system validates the message against established standards: ensuring valid types, length limits (summary header under 100 characters), lowercase imperative phrasing, absence of trailing periods in the header, and proper separation between header, body, and footers.

**Why this priority**: Prevents formatting regressions and guarantees that manually supplied messages conform to the same quality bar as auto-generated ones.

**Independent Test**: Can be tested independently by supplying intentionally malformed messages (e.g., missing type, uppercase verbs, trailing punctuation, excessive length) and verifying that validation catches all violations and provides corrective feedback.

**Acceptance Scenarios**:

1. **Given** a user-supplied message that violates format constraints (e.g., uppercase description or trailing punctuation), **When** validation executes, **Then** the system details each formatting defect and suggests a compliant revision.
2. **Given** a user-supplied message that satisfies all formatting rules, **When** validation executes, **Then** the system confirms that the message is valid and proceeds with commit execution.

---

### Edge Cases

- **Unstaged Changes Present**: When both staged and unstaged modifications exist simultaneously, the system operates exclusively on staged changes without disturbing unstaged work, while informing the contributor that unstaged changes exist.
- **Merge or Rebase in Progress**: When an ongoing merge or rebase is detected, the system warns the contributor and ensures standard merge or resolution commit conventions are preserved.
- **Accidental Inclusion of Credentials or Sensitive Files**: If staged files include common sensitive patterns (such as secret keys, credentials, or environment files), the system flags a warning and halts commit execution to prevent accidental credential leakage into git history.
- **Massive Changesets (e.g., Lockfile or Dependency Updates)**: When large automated changesets are staged, the system classifies them appropriately (e.g., dependency update chore) without truncating essential context.
- **Empty Commit Messages or Whitespace Only**: The system rejects empty or whitespace-only messages and requires a valid summary before executing any commit.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST enforce Conventional Commits formatting (`type(scope): description`) for all created and validated commit messages.
- **FR-002**: System MUST support standard change categories: `feat`, `fix`, `chore`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, and `ci`.
- **FR-003**: System MUST identify the relevant monorepo scope based on affected file paths (e.g., application name, infrastructure, shared tooling, or CI workflow).
- **FR-004**: System MUST verify the git staging area and cleanly handle scenarios where no files are staged by providing actionable guidance.
- **FR-005**: System MUST present proposed commit messages to the contributor for review and confirmation before committing changes to the branch.
- **FR-006**: System MUST allow contributors to edit, customize, or supply their own commit messages subject to format validation.
- **FR-007**: System MUST validate commit message structure, enforcing summary character limits (under 100 characters), imperative mood phrasing, and absence of trailing punctuation in the header.
- **FR-008**: System MUST support prominent flags and structured footer notes for breaking changes.
- **FR-009**: System MUST inspect staged changes for potentially sensitive data (credentials, secret keys, or environment files) and warn the contributor prior to finalizing the commit.
- **FR-010**: System MUST be accessible as an on-demand workflow skill for both human contributors and autonomous AI agents in this repository.

### Key Entities

- **Commit Proposal**: A structured message consisting of Change Category (type), Scope identifier, Imperative Summary, optional Detailed Body, Breaking Change notice, and optional Footers.
- **Monorepo Scope**: The contextual identifier denoting the subsystem or component being modified (e.g., `commifra`, `idea-collector`, `infra`, `repo`, `shared`, `ci`).
- **Staging Changeset**: The collection of staged file additions, updates, and deletions currently prepared for commit in the version control index.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 100% of commits generated and processed through the workflow adhere to the Conventional Commits specification.
- **SC-002**: Contributor can review and execute a standardized commit within 30 seconds from invocation.
- **SC-003**: 100% of detected breaking changes include explicit breaking change indicators in the commit message.
- **SC-004**: Zero credentials, secrets, or temporary configuration files are committed to version control when using the standardized commit workflow.
- **SC-005**: Format validation accurately identifies and reports 100% of non-compliant message headers (e.g., invalid category, trailing period, or missing imperative summary).

## Assumptions

- **Specification Standard**: Conventional Commits v1.0.0 is the governing standard for commit formatting across this monorepo.
- **Repository Context**: Scopes align with top-level applications (`apps/*`), infrastructure definitions (`infra/*`), and shared utilities or CI workflows (`.github/*`). Scopes remain optional for global repository chores.
- **Workflow Interface**: The skill is invoked directly within the developer / agent environment via standard skill invocation mechanisms.
- **Git State**: Git is initialized and tracking files within the workspace root.
