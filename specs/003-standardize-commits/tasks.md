# Tasks: Standardize Commits Skill

**Feature**: `003-standardize-commits`
**Input**: [spec.md](spec.md), [plan.md](plan.md), [data-model.md](data-model.md), [contracts/](contracts/), [research.md](research.md), [quickstart.md](quickstart.md)

**Tests**: Included. `plan.md` commits to a Bash test suite (`scripts/tests/commit-workflow.test.sh`) and SC-001/SC-004/SC-005 are only provable with tests. Write each story's tests first and confirm they fail before implementing.

**Conventions for every task**
- All scripts use `#!/usr/bin/env bash` and `set -euo pipefail`, match the style of `scripts/pr-workflow.sh`, and do not require `jq` or Python (emit JSON with `printf`).
- Never print a matched secret value; never run `git add`, `git commit -a`, `--amend`, `--no-verify`, `git stash` or `git reset` on the user's index.
- Exit codes are exactly those in [contracts/cli-schema.yml](contracts/cli-schema.yml); scope, type and validation rules are exactly those in [contracts/scope-and-type-rules.md](contracts/scope-and-type-rules.md).
- Work on a non-protected branch (this feature uses `feat/003`).

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Skeleton, entry points and test harness

- [X] T001 Create the CLI skeleton as a thin dispatcher plus a shared output library, so later stories never edit the same file: `scripts/commit-workflow.sh` parses the command (`propose`, `validate`, `commit`) and the global `--json` flag, sources `scripts/lib/reporter.sh` and every `scripts/lib/commit-*.sh` that exists, and calls `cmd_propose`, `cmd_validate` or `cmd_commit` (defined in `scripts/lib/commit-cmd-propose.sh`, `commit-cmd-validate.sh`, `commit-cmd-commit.sh`; each initially a stub that exits with an error until its story task replaces it); `scripts/lib/commit-output.sh` defines the exit-code constants `0..7` from `contracts/cli-schema.yml`, `json_escape` and the JSON/text emit helpers; print usage and exit `64` on a missing or unknown command (distinct from the `1` used for an invalid message); make the dispatcher executable
- [X] T002 [P] Add the script entry `"commit": "bash scripts/commit-workflow.sh"` to `package.json` (keep existing keys and ordering otherwise untouched)
- [X] T003 [P] Create the test harness `scripts/tests/commit-workflow.test.sh` (a runner that sources every `scripts/tests/cases/*.sh`, one file per user story) with helpers `mk_repo` (`mktemp -d`, `git init -b main`, set `user.name`/`user.email`, one initial commit, then `git switch -c feat/test`), `assert_eq`, `assert_exit <code> <cmd...>`, `assert_contains`, `assert_not_contains`, a pass/fail counter with a non-zero exit on any failure, and a `trap` that deletes every temp repo; no test cases yet

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Staging inspection, safety detection and the base validator used by every command

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T004 [P] Implement `scripts/lib/commit-staging.sh`: functions to list staged files with status (`git diff --cached --name-status -z`, handling renames `R`), `staged_count`, `unstaged_count`, current branch, `git_state` (`normal`/`merge`/`rebase`/`cherry-pick` via `git rev-parse --git-path MERGE_HEAD`, `rebase-merge`, `rebase-apply`, `CHERRY_PICK_HEAD`), and `require_unprotected_branch` which exits `4` on `main`/`master` with guidance to ask for a branch name and run `git switch -c` (D12; required by constitution Principle VI, not by a spec FR), and define the constant `LARGE_CHANGESET_FILES=200`
- [X] T005 [P] Create `scripts/lib/secret-patterns.sh` exposing `SECRET_PATTERN` (the base set: exactly the regex currently inlined in `check_secret_leak_audit` in `scripts/lib/pr-gates.sh`) and `SECRET_PATTERN_EXTENDED` (base plus the extended formats), both exactly as listed in `contracts/safety-rules.md` section 2, so the two features share one definition and PR-gate behaviour does not change
- [X] T006 Implement `scripts/lib/commit-safety.sh` (depends on T005): `find_sensitive_paths` for the patterns `.env`, `.env.*` (not `*.example`, `*.sample`, `*.template`), `*.pem`, `*.key`, `id_rsa*`, `*.p12`, `*.tfstate*`, `*.tfvars` (not `*.example`), `credentials`; `find_secret_patterns` that greps only the staged diff (`git diff --cached`) with `SECRET_PATTERN_EXTENDED` and reports path and rule name (the rule names in `contracts/safety-rules.md`) but never the matched text; a `--allow-sensitive <path>` allowlist that clears only `sensitive-path` findings, never `secret-pattern` ones (FR-009, SC-004)
- [X] T007 [P] Refactor `check_secret_leak_audit` in `scripts/lib/pr-gates.sh` to `source` `scripts/lib/secret-patterns.sh` and use the base `SECRET_PATTERN` (not the extended set) instead of its inline regex; behaviour and messages must stay identical (verify with `bash scripts/pr-workflow.sh check`)
- [X] T008 [P] Implement the base validator in `scripts/lib/commit-validate.sh`: a `validate_message` function returning a list of issues `{rule, severity, detail, suggestion}` (`severity` is `error` or `warning`; every rule here is an `error`) and covering `empty-message` (empty or whitespace-only), `type-invalid` (must be one of `feat fix chore docs style refactor perf test build ci req infra`), `scope-invalid` (`[a-z0-9][a-z0-9-]*`), `header-format` (`type(scope)?!?: summary` with one `: `) and `header-too-long` (header length strictly less than 100 characters), so `commit` can always re-validate (FR-001, FR-002, FR-006)

**Checkpoint**: Foundation ready - user story work can begin

---

## Phase 3: User Story 1 - Structured Commit Message Generation for Staged Changes (Priority: P1) 🎯 MVP

**Goal**: `propose` inspects the staged set and returns a compliant `type(scope): summary` proposal, or clean guidance when nothing is staged.

**Independent Test**: Stage a change in one component, run `bash scripts/commit-workflow.sh propose --json`, and verify scope, type or candidates, and that no commit was created and the index is unchanged.

### Tests for User Story 1

> Write these first and confirm they FAIL before implementing.

- [X] T009 [P] [US1] Add test cases in `scripts/tests/cases/us1-propose.sh`: single-app change gives `scope: idea-collector`; a `.github/**`-only change gives `type: ci` with `scope: null` and header `ci: …` (scope omitted because it equals the type), while forcing `--type fix` gives `fix(ci): …`; docs-only gives `docs`; a change to only `specs/*/spec.md` and `specs/*/checklists/requirements.md` gives `req`; a change to only `apps/idea-collector/infra/main.tf` gives `type: infra` with `scope: idea-collector`; nothing staged exits `2` with staging guidance; a staged `.env` makes `propose` exit `3`, `propose --allow-sensitive .env` exits `0` and lists the finding with `allowed: true`, and a staged `ghp_` token still exits `3` with that flag; unstaged-only changes are untouched and reported as `unstaged_count`; a lockfile-only change is classified `build` with scope `deps`; a merge in progress (`.git/MERGE_HEAD` present) returns `git_state: merge`, the `.git/MERGE_MSG` text and `warnings: [merge-in-progress]`; staging more than 200 files adds `warnings: [large-changeset]` and still lists every file; one staged plus one modified-unstaged file reports `unstaged_count: 1` and `unstaged-present`; `propose` leaves `git log` and `git diff --cached` identical before and after

### Implementation for User Story 1

- [X] T010 [P] [US1] Implement `scripts/lib/commit-classify.sh` path-to-scope mapping with first-match-wins order `apps/<name>/** -> <name>`, `.github/** -> ci`, `infra/** -> infra`, `packages/**|shared/** -> shared`, `scripts/** -> scripts`, else `repo`; treat lockfiles (`pnpm-lock.yaml`, `go.sum`, `package-lock.json`), `specs/`, `docs/` and same-scope test files as companions that take the main change's scope; also derive each file's `category` (FR-003)
- [X] T011 [US1] In `scripts/lib/commit-classify.sh`, add the type heuristic table from `contracts/scope-and-type-rules.md` section 2, returning a single `type` only when the evidence gives exactly one answer and otherwise `type: null` with ranked `type_candidates`; use `git diff --cached --ignore-all-space --quiet` for `style`; omit the scope for pure `repo` chores and docs
- [X] T012 [US1] Implement `cmd_propose` in `scripts/lib/commit-cmd-propose.sh` (replacing the stub): call `require_unprotected_branch` (exit `4`), exit `2` when nothing is staged, run the safety checks and exit `3` with every finding that is not cleared by a repeatable `--allow-sensitive <path>` option (cleared findings are still listed with `allowed: true` and do not block; credential-content findings are never cleared), apply `--type`, `--scope` (`none` clears it) and `--summary` overrides, build `header` as `type(scope): summary` when all parts exist (omit the scope, and return `scope: null`, when it equals the type), and print human text to stderr and one JSON object matching `json_schemas.propose` to stdout under `--json` with all strings JSON-escaped (FR-001, FR-003, FR-004)
- [X] T013 [US1] Extend `cmd_propose` in `scripts/lib/commit-cmd-propose.sh` for edge cases: when `git_state` is `merge` or `rebase`, return the contents of `.git/MERGE_MSG` as the message with `warnings: [merge-in-progress]`; when more than `LARGE_CHANGESET_FILES` (200) files are staged add `warnings: [large-changeset]` while still listing every file in the JSON; add `unstaged-present` when `unstaged_count > 0`

**Checkpoint**: US1 is independently testable and demonstrable

---

## Phase 4: User Story 2 - Review, Customization, and Safe Commit Execution (Priority: P1)

**Goal**: `commit` creates a commit from exactly the staged set, only with an explicit confirmation of the exact validated message; cancelling leaves everything untouched.

**Independent Test**: Run `commit` without and with `--yes`; verify no commit without confirmation, the exact message in `git log` with confirmation, and an unchanged index after a refusal.

### Tests for User Story 2

- [X] T014 [P] [US2] Add test cases in `scripts/tests/cases/us2-commit.sh`: `commit --message ...` without `--yes` in a non-TTY exits `5` and creates no commit; with `--yes` the message in `git log -1 --format=%B` equals the input exactly and the returned hash matches `git rev-parse --short HEAD`; staged files stay staged after exit `5`; an empty or whitespace-only message exits `1`; running on `main` exits `4`; a staged `.env` blocks with exit `3` and an `--allow-sensitive .env` override commits while a staged `ghp_` token still blocks; each extended format in `contracts/safety-rules.md` (`AKIA...`, `GOCSPX-...`, `xoxb-...`, `github_pat_...`, a PGP key block) blocks with exit `3` and the matched text is absent from stdout and stderr; the lines `client_secret = var.google_client_secret` and `VITE_COGNITO_CLIENT_ID=abc` do not block; unstaged changes remain modified after a commit; a `--trailer "Co-Authored-By: A <a@b.c>"` is appended after a blank line

### Implementation for User Story 2

- [X] T015 [US2] Implement `cmd_commit` in `scripts/lib/commit-cmd-commit.sh` (replacing the stub): read the message from `--message`, `--file` or stdin, run `validate_message` (exit `1` listing every issue when any issue has `severity: error`; `warning` issues are printed and returned in `json_schemas.commit.validation_warnings` but never block the commit), `require_unprotected_branch` (exit `4`), the nothing-staged check (exit `2`) and the safety checks with `--allow-sensitive` (exit `3`), then create the commit with `git commit -F -` fed on stdin and no other flags that alter scope (no `-a`, `--amend`, `--no-verify`), print the `header` and short hash, emit `json_schemas.commit`, and map a git failure to exit `7` (FR-005, FR-006, FR-009)
- [X] T016 [US2] Add confirmation and trailers to `cmd_commit` in `scripts/lib/commit-cmd-commit.sh`: when stdin is not a terminal require `--yes` or exit `5`; when it is a terminal print the full message and read a `y/N` answer (anything but `y` cancels with exit `5` and no changes); accept repeatable `--trailer "Token: value"`, validate each as `Token: value`, and append them after one blank line (FR-005, D13)

**Checkpoint**: US1 and US2 together deliver the MVP; both are independently testable

---

## Phase 5: User Story 3 - Handling Breaking Changes and Multi-Component Impact (Priority: P2)

**Goal**: Breaking changes are decided explicitly and formatted correctly, and mixed-scope commits get a split recommendation without being blocked.

**Independent Test**: Stage a deletion under `apps/*/backend/` and confirm `commit` requires a breaking decision; stage files in two apps and confirm `multi-scope` with a split suggestion.

### Tests for User Story 3

- [X] T017 [P] [US3] Add test cases in `scripts/tests/cases/us3-breaking-scope.sh`: a staged deletion under `apps/idea-collector/backend/` makes `commit` exit `6` until `--breaking "<text>"` (header gains `!` and the footer `BREAKING CHANGE: <text>` is present, SC-003) or `--no-breaking` is given; a change that removes a Terraform `variable` or `output` raises a hint; files in `apps/commifra` and `apps/idea-collector` give `warnings: [multi-scope]` with a `split_suggestion` per scope; a lockfile plus one app file does not warn; `propose` never unstages anything

### Implementation for User Story 3

- [X] T018 [US3] Add breaking-change hints to `scripts/lib/commit-classify.sh` per `contracts/scope-and-type-rules.md` section 3 (deleted or renamed files under `apps/*/backend/`, `packages/`, `shared/`, `contracts/`; removed or renamed `variable`/`output` names in `*.tf`; removed exported symbols; deleted migration or schema files) and return them as `breaking_hints` in the `propose` JSON
- [X] T019 [US3] Implement the breaking flow in `cmd_commit` in `scripts/lib/commit-cmd-commit.sh`: if `breaking_hints` is non-empty and neither `--breaking` nor `--no-breaking` is given, exit `6`; with `--breaking <text>` add `!` before the colon in the header and a `BREAKING CHANGE: <text>` footer, and let the validator enforce `breaking-footer-missing` in both directions (FR-008)
- [X] T020 [US3] Implement the multi-scope check in `scripts/lib/commit-classify.sh` and `propose`: after discounting companion files, if more than one scope remains set `warnings: [multi-scope]`, leave `scope` null and fill `split_suggestion` with per-scope file groups and suggested `git restore --staged <files>` commands, which are printed as text only and never executed

**Checkpoint**: US1 to US3 work independently

---

## Phase 6: User Story 4 - Commit Message Linting and Format Validation (Priority: P3)

**Goal**: `validate` reports every mechanically checkable defect in any message, with a suggested fix.

**Independent Test**: Run `validate` on intentionally malformed messages and on a valid one.

### Tests for User Story 4

- [X] T021 [P] [US4] Add test cases in `scripts/tests/cases/us4-validate.sh`, one per rule id in `contracts/scope-and-type-rules.md` section 4: `Fixed the Thing.` reports `type-invalid`, `uppercase-summary` and `trailing-period` as errors plus `not-imperative` as a warning, together, and exits `1`; `fix(ci): added secret` reports only the `not-imperative` warning, `validate` exits `0`, and `commit` creates the commit and lists the warning; a 100-character header reports `header-too-long` while a 99-character header passes; a missing blank line before the body reports `missing-blank-line`; `!` without a footer and a footer without `!` both report `breaking-footer-missing`; a malformed footer reports `footer-format`; `Merge branch 'x'` is accepted only when `git_state` is `merge`; `req: add new requirements` and `infra(idea-collector): add cognito client` are valid, while `feature: x` is `type-invalid`; a valid message exits `0` (SC-005)

### Implementation for User Story 4

- [X] T022 [US4] Extend `validate_message` in `scripts/lib/commit-validate.sh` with `uppercase-summary`, `trailing-period`, `not-imperative` (first word ending in `ed` or `ing`, or in a third-person `-s` verb list such as `adds fixes updates`, with an allowlist for false positives such as `add embed speed`), `missing-blank-line`, `breaking-footer-missing` and `footer-format` as errors, with `not-imperative` set to `severity: warning` (all others `error`), accepting git-generated `Merge`/`Revert`/`fixup!`/`squash!` messages only in `merge`/`rebase` state; give a computed `suggestion` where possible (for example lowercase the first letter, strip the trailing period)
- [X] T023 [US4] Implement `cmd_validate` in `scripts/lib/commit-cmd-validate.sh` (replacing the stub): accept the message as an argument, `--file <path>` or `-` for stdin, report all issues (not just the first) with their `severity` as text or `json_schemas.validate`, exit `0` when there are no error-level issues and `1` otherwise, and never touch git state (FR-006, FR-007)

**Checkpoint**: All user stories independently functional

---

## Phase 7: Skill, Documentation & Polish

**Purpose**: The on-demand skill (FR-010) and cross-cutting finish

- [X] T024 [P] Create `.agents/skills/speckit-commit/SKILL.md` implementing `contracts/skill-contract.md`: frontmatter modelled on `.agents/skills/speckit-pr/SKILL.md`, a Branch Guard section mirroring the other speckit skills, the seven-step flow (guard, propose, refine, breaking check, review, commit, report), the failure-mapping table, and the guarantees list; the skill must always delegate to `scripts/commit-workflow.sh` and show the exact final message and obtain an explicit confirmation before running `commit --yes` (a confirmation covers only the message shown; re-ask after any edit; never pass `--yes` otherwise), then include in the file a short pre-commit checklist the skill follows: branch guard done, message validated (no errors), message shown, confirmation received
- [X] T025 Copy the skill to `.claude/skills/speckit-commit/SKILL.md` (identical content) so Claude Code loads it (depends on T024)
- [X] T026 [P] Register `speckit-commit` in the skills list in `scripts/lib/skills-audit.sh` and confirm `bash scripts/setup-dev.sh --verify-skills` still passes
- [X] T027 [P] Add one line for `/speckit-commit` to the Workflow section of `README.md` next to `/speckit-pr`
- [X] T028 Run `bash -n` on every new script, `bash scripts/tests/commit-workflow.test.sh`, `bash scripts/pr-workflow.sh check`, and each scenario in `quickstart.md` in a scratch clone; fix any failure and record the results in the PR description
- [ ] T029 CI wiring for `scripts/tests/commit-workflow.test.sh` in a new `.github/workflows/` job (**requires explicit approval; `AGENTS.md` forbids changing CI workflows without it. Do not start unless the user instructs it**)

---

## Dependencies & Execution Order

- **Phase 1** has no dependencies; T002 and T003 can run alongside T001.
- **Phase 2** depends on Phase 1 and blocks all stories. T004, T005 and T008 can run in parallel; T006 needs T005; T007 needs T005.
- **US1 (Phase 3)** depends on Phase 2. **US2 (Phase 4)** depends only on Phase 2 and T001 (the output helpers live in `commit-output.sh`, not in `propose`), so it does not wait for US1's heuristics. **US3 (Phase 5)** depends on US1 (classification) and US2 (`commit`). **US4 (Phase 6)** depends only on Phase 2 (T008) and can run in parallel with US1/US2. Parallel stories never share a file: each command has its own `commit-cmd-*.sh`, each story its own `tests/cases/*.sh`. Within one file the tasks are ordered (`commit-cmd-commit.sh`: T015, T016, then T019; `commit-classify.sh`: T010, T011, then T018, T020).
- **Phase 7** depends on all the stories it documents; T029 is blocked on explicit approval.

```text
T001 -> (T002, T003) -> T004/T005/T008 -> T006, T007
                               |
        +----------------------+----------------------+
        v                      v                      v
   US1 (T009-T013)       US4 (T021-T023)        US2 (T014-T016)
        |                                             |
        +----------------------+-----------------------+
                               |
                               v
                         US3 (T017-T020) [needs US1 + US2] -> Phase 7 (T024-T028) -> T029 (approval)
```

## Parallel Execution Examples

- **Setup**: after T001, run T002 and T003 together.
- **Foundational**: T004, T005 and T008 touch different files; then T006 and T007 together.
- **US1**: T009 (tests) and T010 (scope map) in parallel; T011 follows T010 (same file).
- **US1, US2 and US4** can proceed in parallel by three people once Phase 2 is done, because they edit disjoint files (`commit-cmd-propose.sh`, `commit-cmd-commit.sh`, `commit-cmd-validate.sh`).
- **Polish**: T024, T026 and T027 in parallel; T025 after T024.

## Implementation Strategy

- **MVP**: Phases 1 to 4 (US1 and US2). That gives a proposal and a safe, confirmed commit, which is the P1 value in the spec. Stop and validate with quickstart scenarios 1 to 4, 8 and 9.
- **Incremental delivery**: add US3 (breaking and multi-scope) next, then US4 (full linting), then the skill and docs. Each phase ends at a checkpoint that can be shipped on its own.
- **Order within a story**: tests (confirm they fail), libraries, command wiring.
- **Out of scope here**: CI wiring (T029) and changing the tracked `apps/idea-collector/frontend/.env` practice noted in `research.md` D9.
