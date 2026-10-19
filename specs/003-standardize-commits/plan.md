# Implementation Plan: Standardize Commits Skill

**Branch**: `feat/003` (spec: `003-standardize-commits`) | **Date**: 2026-10-18 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/003-standardize-commits/spec.md`

## Summary

Add an on-demand `/speckit-commit` skill that turns the staged changes into a validated Conventional Commits message, shows it for review, and only then commits. It follows the dual-mode pattern already used by `/speckit-pr` (feature 007): a Bash CLI (`scripts/commit-workflow.sh` with helpers in `scripts/lib/commit-*.sh`, exposed as `pnpm run commit`) holds all deterministic logic (staging inspection, scope detection, type heuristics, sensitive-file and secret detection, message validation, the actual `git commit`), and a companion skill gives humans and agents the conversational layer (reading the diff to refine the type and summary, asking for confirmation, handling breaking changes). The CLI never commits without an explicit confirmation, never stages files, and refuses to run on `main`/`master` (Constitution VI).

## Technical Context

**Language/Version**: Bash 5+ (same as `scripts/pr-workflow.sh`); Python 3 is not required

**Primary Dependencies**: `git` only; `jq` is NOT assumed (it is not installed on the reference dev machine), so JSON output is emitted with `printf`

**Storage**: N/A (reads the git index; writes only the commit)

**Testing**: Plain-Bash test script `scripts/tests/commit-workflow.test.sh` that builds throwaway git repos in `mktemp -d` and asserts on CLI output and exit codes; plus the manual scenarios in [quickstart.md](quickstart.md)

**Target Platform**: Linux, macOS, Windows WSL2 (same as the existing scripts)

**Project Type**: Developer CLI tool, shell libraries, and a Spec Kit agent skill

**Performance Goals**: `propose` completes in < 2 s for up to 50 staged files or 1 MB of staged diff; contributor can review and commit in < 30 s (SC-002), which is dominated by human review and is checked by hand while running quickstart scenarios 1 and 4 (no automated timing test)

**Constraints**:
- Operate on the staged set only; never run `git add`, `git commit -a`, `git stash` or touch unstaged work (edge case: unstaged changes present)
- Halt, without committing, on sensitive staged files or secret patterns (FR-009, SC-004), with an explicit per-path override for deliberate cases
- Refuse to commit on `main`/`master` and during an unresolved conflict state
- No dependency on `jq`/Python; must run under `set -euo pipefail`

**Scale/Scope**: One repository, a handful of contributors and agents; staged sets from 1 file up to lockfile-sized changesets

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Checked against constitution v1.1.0.

- **I. AI-Native SDLC Pipeline**: PASS. Gives agents a deterministic, auditable way to commit and humans the same one. Scope is limited to FR-001 to FR-010; no speculative extras.
- **II. Infrastructure as Code**: PASS (not applicable). No infra or state is touched.
- **III. Automated Quality & CI/CD Gates**: PASS, with a recorded ruling. Lint/typecheck/tests for the script are the Bash test suite (`scripts/tests/commit-workflow.test.sh`) and must pass locally before the PR is opened, as Principle III and `AGENTS.md` require of agents. **Ruling (confirmed by the owner)**: developer tooling under `scripts/` is not a "service or package", so Principle III's per-service CI-workflow clause does not apply to it. Running the suite in GitHub Actions would edit `.github/workflows/`, which Agent Constraints forbid without explicit instruction, so it was a separate task (T029) that started only on explicit approval, and it has since been done as a standalone workflow. If the owner later decides `scripts/` should be covered by CI, T029 becomes in scope and this ruling is replaced.
- **IV. Strict Security & Credential Handling**: PASS. The feature itself enforces this principle: it blocks `.env`-style files, private keys, state files and token patterns before a commit is created, and never logs matched secret values.
- **V. Codebase Respect & Localization**: PASS. Reuses the `scripts/` + `scripts/lib/` layout, `pnpm run` entry points, logging helpers from `scripts/lib/reporter.sh`, and the secret regex from `scripts/lib/pr-gates.sh` (shared, not copied).
- **VI. Branch Discipline & Naming**: PASS. The CLI mirrors the `main`/`master` block and the skill documents the branch rules, so a commit is never made on a protected branch.

**Post-design re-check (after Phase 1)**: PASS. No new violations; the CI wiring noted under III was approved and done (T029). No Complexity Tracking entries needed.

## Project Structure

### Documentation (this feature)

```text
specs/003-standardize-commits/
├── plan.md              # This file
├── research.md          # Phase 0: decisions, rationale, alternatives, open risks
├── data-model.md        # Phase 1: Commit Proposal, Monorepo Scope, Staging Changeset
├── quickstart.md        # Phase 1: runnable validation scenarios
├── contracts/
│   ├── cli-schema.yml       # scripts/commit-workflow.sh commands, flags, exit codes, JSON
│   ├── skill-contract.md    # /speckit-commit behaviour and conversation flow
│   ├── scope-and-type-rules.md  # path -> scope map, type heuristics, validation rules
│   └── safety-rules.md      # sensitive paths and credential patterns (FR-009, SC-004)
├── checklists/
│   └── requirements.md  # Spec quality checklist (existing)
└── tasks.md             # Phase 2 output (/speckit-tasks - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
scripts/
├── commit-workflow.sh           # thin dispatcher (propose | validate | commit)
├── lib/
│   ├── commit-output.sh         # exit-code constants, JSON escaping, text/JSON emit helpers
│   ├── commit-staging.sh        # staging/branch/merge-state inspection, changed-path listing
│   ├── commit-classify.sh       # path -> scope, heuristic type, breaking-change hints
│   ├── commit-validate.sh       # Conventional Commits + repo rules validation
│   ├── commit-safety.sh         # sensitive-path and secret-pattern detection
│   ├── secret-patterns.sh       # SECRET_PATTERN shared with pr-gates.sh
│   ├── commit-cmd-propose.sh    # cmd_propose (US1)
│   ├── commit-cmd-commit.sh     # cmd_commit (US2, US3)
│   ├── commit-cmd-validate.sh   # cmd_validate (US4)
│   └── pr-gates.sh              # existing; sources secret-patterns.sh (behaviour unchanged)
└── tests/
    ├── commit-workflow.test.sh  # runner + harness helpers
    └── cases/                   # one file per user story: us1-propose.sh, us2-commit.sh,
                                 #   us3-breaking-scope.sh, us4-validate.sh

.agents/skills/speckit-commit/SKILL.md   # skill source (matches existing .agents/skills layout)
.claude/skills/speckit-commit/SKILL.md   # copy loaded by Claude Code
package.json                             # adds "commit": "bash scripts/commit-workflow.sh"
README.md                                # one-line mention of /speckit-commit in the Workflow section
scripts/lib/skills-audit.sh              # register the new skill in the audit list
```

**Structure Decision**: Single-purpose tooling, so it lives in the shared `scripts/` tree exactly like feature 007, not under `apps/`. Logic is split into small libraries by responsibility so each is testable from the Bash test suite and so parallel stories never edit the same file (one `commit-cmd-*.sh` per command, one `tests/cases/*.sh` per story) and reusable (the safety library shares its secret regex with `pr-gates.sh`). The skill is a thin conversational wrapper that always delegates to the CLI, which keeps human and agent behaviour identical (FR-010).

## Complexity Tracking

No constitution violations to justify.
