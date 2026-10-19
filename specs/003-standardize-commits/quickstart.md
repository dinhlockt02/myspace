# Quickstart: Validate the Standardize Commits Skill

**Feature**: `003-standardize-commits`

Runnable scenarios that prove the feature end to end. Interfaces are defined in [contracts/cli-schema.yml](contracts/cli-schema.yml); entities in [data-model.md](data-model.md). Run them in a scratch clone, not in your working copy.

## Prerequisites

- `git` and Bash 5+ (no `jq` needed)
- A feature branch (not `main`): `git switch -c feat/commit-skill-trial`
- Implementation complete (`/speckit-implement`)

## Setup

```bash
SCRATCH=$(mktemp -d) && git clone . "$SCRATCH" && cd "$SCRATCH" && git switch -c feat/commit-skill-trial
```

## Scenario 1 - Proposal for a single-scope change (US1, FR-001, FR-003)

```bash
echo "// note" >> apps/idea-collector/backend/main.go
git add apps/idea-collector/backend/main.go
bash scripts/commit-workflow.sh propose --json
```

Expected: `status: ok`, `scope: idea-collector`, a `type` or ranked `type_candidates`, no safety findings. `git status` shows the file still staged and no new commit.

## Scenario 2 - Repo-wide change gets an overarching scope (US1 scenario 2)

```bash
echo "" >> .github/workflows/on_push.yml && git add .github/workflows/on_push.yml
bash scripts/commit-workflow.sh propose --json
```

Expected: `type: ci`, `scope: null` and a header starting `ci:` (the scope is omitted because it equals the type). With `--type fix` the header starts `fix(ci):`.

## Scenario 3 - Nothing staged (US1 scenario 3, FR-004)

```bash
git reset -q && bash scripts/commit-workflow.sh propose; echo "exit=$?"
```

Expected: exit `2` and a message explaining how to stage files.

## Scenario 4 - Review, edit, cancel, confirm (US2, FR-005, FR-006)

```bash
git add apps/idea-collector/backend/main.go
bash scripts/commit-workflow.sh commit --message "fix(idea-collector): handle empty claims" ; echo "exit=$?"   # exit 5, not confirmed
git log --oneline -1                                   # unchanged: cancelled/unconfirmed leaves history alone
bash scripts/commit-workflow.sh commit --message "fix(idea-collector): handle empty claims" --yes
git log --oneline -1                                   # new commit with the exact message
```

## Scenario 5 - Validation catches every defect (US4, FR-007, SC-005)

```bash
bash scripts/commit-workflow.sh validate "Fixed the Thing."; echo "exit=$?"
bash scripts/commit-workflow.sh validate "fix(idea-collector): handle empty claims"; echo "exit=$?"
bash scripts/commit-workflow.sh validate "fix(ci): added secret"; echo "exit=$?"
```

Expected: first exits `1` listing errors `type-invalid`, `uppercase-summary`, `trailing-period` and the warning `not-imperative`; second exits `0`; third exits `0` and shows only the `not-imperative` warning (warnings never block a commit).

## Scenario 6 - Breaking change (US3, FR-008, SC-003)

```bash
git rm -q apps/idea-collector/backend/handlers/auth.go
bash scripts/commit-workflow.sh commit --message "refactor(idea-collector): remove google token handler" --yes ; echo "exit=$?"   # exit 6
bash scripts/commit-workflow.sh commit --message "refactor(idea-collector): remove google token handler" --breaking "POST /api/auth/google is gone" --yes
git log -1 --format=%B                                 # header has "!" and a BREAKING CHANGE: footer
```

## Scenario 7 - Multi-scope warning (US3 scenario 2)

```bash
touch apps/commifra/x.txt apps/idea-collector/y.txt && git add apps/commifra/x.txt apps/idea-collector/y.txt
bash scripts/commit-workflow.sh propose --json
```

Expected: `warnings` contains `multi-scope` and `split_suggestion` lists both scopes; nothing is unstaged.

## Scenario 8 - Sensitive data blocked (FR-009, SC-004)

```bash
# Build the fake key at runtime so this document itself contains no secret-looking literal
printf 'AWS_SECRET_ACCESS_KEY=%s\n' "$(printf 'a%.0s' {1..40})" > .env.production && git add -f .env.production
bash scripts/commit-workflow.sh commit --message "chore: add config" --yes ; echo "exit=$?"
```

Expected: exit `3` with two findings for `.env.production` (a `sensitive-path` rule and a `secret-pattern` rule), the key text is not printed, and no commit is created. Re-run with `--allow-sensitive .env.production`: the path finding is cleared but the secret-pattern finding still blocks (exit `3`). Replace the file content with a non-secret value such as `VITE_API_URL=https://example.test` and re-run with the override: the commit succeeds.

## Scenario 9 - Protected branch (Constitution VI)

```bash
git switch -q main && bash scripts/commit-workflow.sh commit --message "chore: x" --yes ; echo "exit=$?"
```

Expected: exit `4` with guidance to ask for a branch name.

## Scenario 10 - Unstaged work and merge state (edge cases)

Stage one file while leaving another modified: `propose` reports `unstaged_count: 1` and the later commit leaves the unstaged file modified. Start a conflicting merge: `propose` returns `git_state: merge` and the existing merge message.

## Automated suite

```bash
bash scripts/tests/commit-workflow.test.sh
```

Covers the scenarios above in throwaway repositories. Success: all tests pass.
