# Research & Architectural Decisions: Post-Implementation PR Management Skills

**Feature**: `007-manage-pr-workflow`
**Date**: 2026-10-12
**Status**: Completed

## Overview

This research document consolidates technical choices, integration patterns, and architectural decisions for implementing post-implementation Pull Request (and Merge Request alias) management skills within the Myspace monorepo.

---

## Key Decisions & Rationales

### 1. Dual-Layer Architecture: CLI Script + AI Agent Skill

- **Decision**: Implement a modular shell CLI (`scripts/pr-workflow.sh` with helper modules in `scripts/lib/`) paired with an AI companion skill (`.agents/skills/speckit-pr/SKILL.md`).
- **Rationale**:
  - Parallels the established repository pattern used in `scripts/setup-dev.sh` and `.agents/skills/dev-onboarding/SKILL.md`.
  - Enables direct execution in automated CI/CD pipelines, local developer terminals (`pnpm run pr`), and AI agent sessions (`/speckit-pr`).
  - Keeps the AI agent skill lightweight by orchestrating deterministic CLI commands and formatting conversational responses.
- **Alternatives Considered**:
  - *Pure Node.js/TypeScript CLI*: Would introduce additional compilation and build steps. Shell scripts directly leverage `git`, `gh`, `curl`, and existing repository tools without overhead.
  - *Agent-only prompt instructions without CLI*: Lacks deterministic repeatability in standalone terminal or CI environments; violates monorepo dual-mode onboarding/SDLC conventions.

---

### 2. Dual GitHub Communication Strategy: GitHub CLI (`gh`) with REST API Fallback

- **Decision**: Prioritize GitHub CLI (`gh`) when installed and authenticated (`gh auth status`), with automatic fallback to direct GitHub REST API v3 calls via `curl` and `GITHUB_TOKEN`.
- **Rationale**:
  - Developers on workstations frequently use `gh` CLI which already caches OAuth credentials, avoiding manual token generation.
  - Headless environments, CI runners, and minimal container sandboxes typically provide `GITHUB_TOKEN` rather than interactive `gh` authentication.
  - Standardizing fallback on `https://api.github.com/repos/{owner}/{repo}/pulls` ensures compatibility across both environments.
- **Alternatives Considered**:
  - *`gh` CLI only*: Breaks in containerized or minimal environments where `gh` is not installed or lacks interactive login.
  - *REST API only*: Requires human developers to manually create, export, and maintain personal access tokens even when `gh` is already logged in.

---

### 3. Automated Description Generation adhering to Monorepo Constitution (Principle I)

- **Decision**: The PR description is synthesized dynamically from the active feature specification (`specs/<feature>/spec.md`), task progress (`specs/<feature>/tasks.md`), and git commit log, structured around Constitution Principle I:
  1. **Intent**: High-level motivation and business objective (from spec user stories).
  2. **Scope**: Exact touched projects and packages (mapped from `git diff --name-only origin/main...HEAD`).
  3. **Completed Tasks**: Checkbox list of finished tasks extracted from `tasks.md`.
  4. **Verification Steps**: Concrete instructions for reviewers (lint, test, build commands, and demo steps).
  5. **Pre-Flight Quality Gates**: Verification badge checklist (lint, typecheck, unit tests, secret scan).
- **Rationale**:
  - Constitution Principle I explicitly demands: *"Every PR MUST include a clear intent, scope, and verification steps. Speculative changes are strictly prohibited."*
  - Automating this synthesis guarantees 100% adherence to project governance while eliminating repetitive developer paperwork.
- **Alternatives Considered**:
  - *Static PR template*: Leaves burden of writing on developers and agents, leading to inconsistent quality and omitted verification steps.
  - *Pure commit log dump*: Commit messages lack higher-level business intent, acceptance criteria, and explicit verification steps.

---

### 4. Default to Draft Pull Request Mode with Direct Publish Flag

- **Decision**: New Pull Requests are created in **Draft mode** by default, with support for `--ready` / `--publish` flags to open directly for team review.
- **Rationale**:
  - In an AI-native monorepo where autonomous agents generate code and open PRs, creating draft PRs allows human authors to review diffs and generated descriptions before notifying team reviewers or triggering resource-intensive deployment pipelines.
  - Promotes safety and confidence without preventing direct publishing when explicitly desired.
- **Alternatives Considered**:
  - *Always Ready for Review*: Can trigger premature reviewer pings and CI notifications before author sanity-checking is complete.
  - *Interactive prompt only*: Breaks unattended automation scripts and non-interactive agent execution.

---

### 5. Pre-Flight Quality Gate Enforcement

- **Decision**: The PR workflow executes a pre-flight audit before opening or updating a remote PR:
  1. `git status --porcelain`: Verifies working tree cleanliness (blocks uncommitted/unstaged changes).
  2. Monorepo quality check: Executes `pnpm nx run-many -t lint,test,build` for affected projects and Go tests (`go test ./...`) for backend projects.
  3. Secret leak scan: Inspects staged/committed diff for accidental credentials, private keys, or tokens.
  4. Remote branch sync: Ensures local commits are pushed to `origin/<branch>` with upstream tracking.
- **Rationale**:
  - Constitution Principle III states: *"Agents MUST run lint, typecheck, and tests before opening a PR."*
  - Constitution Principle IV states: *"Under no circumstances may secrets, credentials, or sensitive data be committed."*
  - Blocking non-compliant PRs locally saves developer CI time and prevents broken builds from polluting GitHub.
- **Alternatives Considered**:
  - *Rely solely on GitHub Actions CI*: Wastes remote CI runner resources on issues that can be caught in seconds locally.
  - *Skip pre-flight checks on update*: Can result in broken intermediate commits pushed to active review branches.

---

### 6. Idempotent PR Synchronization & State Preservation

- **Decision**: When `--update` is passed (or `--create` is invoked on a branch with an existing PR), the tool queries the open PR for the branch, updates the title/body via `gh pr edit` or `PATCH /repos/{owner}/{repo}/pulls/{number}`, and preserves:
  - Existing PR comments and discussion threads.
  - Reviewer approvals and assigned reviewers.
  - Any custom user notes delineated within explicit HTML comment markers (e.g., `<!-- custom-notes -->`).
- **Rationale**:
  - Iterative reviews require pushing new commits without destroying reviewer conversations or losing approval context.
- **Alternatives Considered**:
  - *Closing and re-opening PRs*: Disrupts discussion threads, resets review approvals, and generates review noise.
  - *Overwriting entire body blindly*: Overwrites human reviewer notes or manual edits.

---

### 7. Integration with Developer Onboarding Suite (`/dev-onboarding`)

- **Decision**: Register `/speckit-pr` into the repository AI skills audit suite by adding it to `expected_skills` in `scripts/lib/skills-audit.sh`, updating `.agents/skills/dev-onboarding/SKILL.md`, and documenting the post-implementation workflow in `docs/ONBOARDING.md`.
- **Rationale**:
  - The repository maintains a dual-mode onboarding system (`setup-dev.sh --verify-skills` and `/dev-onboarding`).
  - Registering the new skill ensures that `/dev-onboarding` audits all 11 skills and guides new developers on how to open and manage PRs after implementing workflows.
- **Alternatives Considered**:
  - *Leaving onboarding un-updated*: Causes documentation and audit drift where newly added skills are omitted from onboarding checks.

---

## Technology Stack Summary

| Component | Choice | Justification |
| :--- | :--- | :--- |
| **CLI Implementation** | Bash 5+ | Lightweight, native POSIX tooling, aligns with existing `scripts/setup-dev.sh` |
| **Git Client** | `git` (CLI) | Universal, tracks working tree and branch remotes |
| **GitHub Interaction** | `gh` CLI + REST API | Seamless developer OAuth + robust headless token fallback |
| **Quality Gate Runner**| Nx + Go toolchain | Fast affected project execution matching CI pipelines |
| **AI Agent Skill** | Spec-Kit Markdown (`SKILL.md`) | Interactive pairing in Antigravity IDE with `/speckit-pr` |
| **Payload Format** | Markdown + JSON | Structured human-readable PR bodies with machine-readable CLI output |
