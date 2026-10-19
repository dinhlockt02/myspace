# Research: Standardize Commits Skill

**Feature**: `003-standardize-commits` | **Date**: 2026-10-18

The spec had no `NEEDS CLARIFICATION` markers. This document records the design decisions the plan depends on, plus risks found while reading the repository.

## D1. Delivery shape: CLI plus companion skill

- **Decision**: Implement `scripts/commit-workflow.sh` (with `scripts/lib/commit-*.sh`) and a thin `/speckit-commit` skill that calls it.
- **Rationale**: Feature 007 already established this dual mode. Deterministic checks (staged set, scope, secrets, validation) belong in code so a human and an agent get identical results (FR-010, SC-001, SC-005); judgement (is this a `feat` or a `refactor`? is it breaking?) belongs to the reader of the diff, so the skill adds that layer.
- **Alternatives considered**: A pure skill with no script (rejected: validation and secret checks would be re-derived by the model on each run and could not be tested); a `commit-msg` git hook or commitlint (rejected as the primary mechanism: it only validates after the fact, cannot propose a message, and adds a Node toolchain dependency; it can be added later using the same validator).

## D2. Skill name and locations

- **Decision**: Name it `speckit-commit` (`/speckit-commit`). Author it in `.agents/skills/speckit-commit/SKILL.md` and copy it to `.claude/skills/speckit-commit/SKILL.md`.
- **Rationale**: The repo keeps skills in `.agents/skills/` (audited by `scripts/lib/skills-audit.sh`, used by 007) and Claude Code loads `.claude/skills/`. The two trees already differ per skill, so the copy is kept deliberately small and the skills-audit list is extended.
- **Alternatives**: `standardize-commits` (rejected: breaks the `speckit-*` naming of every other repo skill).

## D3. Commit format and type set

- **Decision**: Conventional Commits v1.0.0, header `type(scope)!: summary`, types exactly as FR-002: `feat fix chore docs style refactor perf test build ci req infra`.
- **Rationale**: Matches the spec and the current history (`fix(ci): ...`, `docs: ...`, `feat: ...`).
- **Owner decision (resolved)**: `req` and `infra` are accepted as commit types. History already contains `req:` (commit `8e1d070`, which only added `spec.md` and `checklists/requirements.md` files) and the branch rules use both as branch types, so accepting them keeps commit types aligned with branch types. `req` is proposed when the staged set is only requirement specs (`specs/*/spec.md`, `specs/*/checklists/requirements.md`); other documents under `specs/` stay `docs`. `infra` is proposed when the staged set is only infrastructure definitions (`infra/**`, `apps/*/infra/**`); the scope still comes from the path, for example `infra(idea-collector): ...`.

## D4. Scope detection

- **Decision**: Deterministic path-to-scope map (full table in [contracts/scope-and-type-rules.md](contracts/scope-and-type-rules.md)): `apps/<name>/**` becomes `<name>` (`idea-collector`, `commifra`); `.github/**` becomes `ci`; `infra/**` becomes `infra`; `packages/**` and `shared/**` become `shared`; `scripts/**` becomes `scripts`; anything else (root files, `docs/`, `.claude/`, `.agents/`, `.specify/`, `specs/`) becomes `repo` or no scope for pure chores.
- **Rationale**: Mirrors how recent commits were already scoped (`idea-collector`, `ci`, `scripts`) and the scope list in the spec's Monorepo Scope entity. Scope is optional per the spec's assumptions.
- **Edge**: `apps/idea-collector/infra/**` is scoped `idea-collector`, not `infra`, because the project owns it; top-level `infra/` is the shared scope.
- **Alternatives**: One scope per top-level directory (rejected: `apps` alone says nothing); free-text scopes (rejected: untestable against SC-001).

## D5. Type inference is heuristic, confirmed by a person

- **Decision**: The CLI proposes a type from file evidence (docs-only becomes `docs`, test-only becomes `test`, `.github/**` becomes `ci`, lockfile and manifest changes become `build(deps)`, whitespace-only becomes `style`); anything ambiguous returns `type: null` with ranked candidates. The skill reads the diff to pick the final type and write an imperative summary, and the contributor confirms.
- **Rationale**: File paths cannot tell `feat` from `fix` from `refactor`. Claiming certainty would violate "never hallucinate" and produce confidently wrong history.
- **Alternatives**: Always ask (rejected: slower than SC-002); always guess `feat` (rejected: wrong most of the time).

## D6. Message validation rules (FR-007, SC-005)

- **Decision**: Reject when any rule fails and report every failure with a suggested fix: valid type; optional `(scope)` of `[a-z0-9-]+`; optional `!`; `: ` separator; header length strictly under 100 characters; summary starts lowercase; no trailing period; imperative mood; blank line between header and body; `BREAKING CHANGE:` footer present when `!` is used; non-empty and not whitespace-only.
- **Severity**: `not-imperative` is a warning, every other rule is an error. A heuristic that can misjudge a good summary must not be able to block a commit, so `commit` ignores warnings and `validate` exits `0` when only warnings remain.
- **SC-005 scope**: because imperative mood cannot be checked exactly, SC-005 covers the mechanically checkable defects (100%) and treats imperative mood as best-effort.
- **Imperative mood is a heuristic**: reject a first word ending in `ed` or `ing`, or in a short `-s` verb list (`adds`, `fixes`, `updates`...), and accept everything else. A small allowlist covers false positives (`add`, `embed`, `speed`...). The limitation is documented so SC-005's "100%" is read as 100% of the *mechanically checkable* defects.
- **Alternatives**: NLP or an LLM call for mood (rejected: non-deterministic, breaks offline use).

## D7. Breaking changes (FR-008, SC-003)

- **Decision**: The CLI cannot prove a change is breaking, so it surfaces hints (deleted or renamed exported paths, changes to `*.tf` variables or outputs, API route files, `contracts/`, DynamoDB or schema files) and `commit` requires either `--breaking "<explanation>"` or `--no-breaking`. A breaking commit gets `!` in the header and a `BREAKING CHANGE:` footer.
- **Rationale**: Making the question mandatory when a hint fires is the only way to reach SC-003 without false certainty.

## D8. Splitting broad commits (US3)

- **Decision**: If staged paths map to more than one scope after discounting companions (lockfiles, `docs/`, `specs/`, tests for the same scope), return `warnings: [multi-scope]` with a per-scope file grouping and suggested `git restore --staged` commands. It warns; it never blocks or unstages.
- **Rationale**: The spec asks for caution and recommendations, not enforcement. Squash-merge PRs make strict atomicity less critical here.

## D9. Sensitive-file and secret protection (FR-009, SC-004)

- **Decision**: Two layers, both blocking by default.
  1. Path patterns: `.env`, `.env.*` (except `*.example`, `*.sample`, `*.template`), `*.pem`, `*.key`, `id_rsa*`, `*.p12`, `*.tfstate*`, `*.tfvars` (except `*.example`), `credentials`, `.npmrc` with `_authToken`.
  2. Content patterns on the staged diff: the existing PR-gate regex (AWS secret key, `ghp_` tokens, private key blocks) as a shared base set, extended with high-confidence formats (AWS access key ID, Google OAuth client secret `GOCSPX-`, Slack, GitHub token family, fine-grained PAT, PGP key). The full list, with rationale, is in [contracts/safety-rules.md](contracts/safety-rules.md).
  3. **Deliberate limit**: free-form secrets such as `password = value` are not matched, because content findings cannot be overridden and a generic pattern would produce false positives nobody could clear. SC-004 is therefore a guarantee about the listed formats, and review still has to catch the rest. Each pattern was checked against the tracked files of this repository and matched none.
- **Override**: `--allow-sensitive <path>` per path, never a global switch, and the match is never printed. This is consistent with FR-009/SC-004, which allow an explicit per-path override for sensitive file paths and forbid overriding credential or private-key content.
- **Repo-specific risk found**: `apps/idea-collector/frontend/.env` is *tracked on purpose* (Vite needs the public Cognito IDs at build time) even though `.gitignore` lists `.env`. Editing it was a legitimate recent commit (PR 16). With the default rules this skill would block that commit, so the per-path override exists and the skill must explain it instead of silently failing. A longer-term fix (inject public config from CI instead of a tracked `.env`) is out of scope here.

## D10. Safe execution (FR-005, US2)

- **Decision**: `propose` is read-only. `commit` takes the final message, re-validates it, re-runs the safety checks, then runs `git commit -F -` with the message on stdin and returns the new short hash. It never passes `-a`, `--no-verify` or `--amend`. Cancelling is simply not calling `commit`, so staging stays untouched. A non-interactive run requires `--yes`; the skill does the confirmation through the chat.
- **Alternatives**: Having the script prompt on a TTY (rejected: agents have no TTY; kept only as a convenience when stdin is a terminal).

## D11. Git state edge cases

- **Decision**: Detect `MERGE_HEAD`, `rebase-merge/`, `rebase-apply/`, `CHERRY_PICK_HEAD`. During a merge or rebase, `propose` returns the existing `.git/MERGE_MSG` as the message and marks `mode: merge`, validation is relaxed to "non-empty" for git-generated merge messages, and the user is warned. Unstaged changes are reported as a count, never touched. A massive changeset (> 200 staged files, the `LARGE_CHANGESET_FILES` constant in `commit-staging.sh`: beyond roughly this size a per-file review is no longer realistic, so the warning tells the contributor to check the grouping and not to rely on the file list; or any lockfile) is classified as `build(deps)` when it is lockfile-only, otherwise it is summarized by scope without truncating the file list in JSON output.

## D12. Protected branches (Constitution VI)

- **Decision**: `commit` exits non-zero on `main`/`master` with the same guidance as the Claude hook (ask for a branch name, `git switch -c`). The Claude `PreToolUse` hook already blocks `git commit` there; the CLI check makes the behaviour hold for humans and other agents too.

## D13. Attribution trailers

- **Decision**: The CLI accepts repeatable `--trailer "Key: value"`. The skill passes the session's required attribution (for example `Co-Authored-By`) here, so the footer is valid and separated by a blank line. Footers are validated for `Token: value` shape.

## D14. Testing and CI

- **Decision**: A plain-Bash suite (`scripts/tests/commit-workflow.test.sh`) creating temp repos, runnable locally via `pnpm run commit -- test`. There is no existing test runner for shell scripts and adding bats would add a dependency.
- **CI wiring**: Running it in GitHub Actions needs a workflow change, which `AGENTS.md` forbids without explicit instruction, so it is tracked as a separate approved task and not assumed.

## Open items for the owner

1. ~~Should `req` (and `infra`) be accepted as commit types?~~ Resolved: yes (D3).
2. Is the tracked `apps/idea-collector/frontend/.env` expected to stay? Default: yes, with the `--allow-sensitive` override (D9).
3. Approval to add CI wiring for the new test suite (D14).
