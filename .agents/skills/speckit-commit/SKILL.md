---
name: "speckit-commit"
description: "Standardize commits: inspect the staged changes, propose a validated Conventional Commits message, ask for confirmation, and commit only what is staged."
argument-hint: "Optional message hint, or --validate \"<message>\" / --breaking \"<text>\""
compatibility: "Requires a git repository with scripts/commit-workflow.sh (spec-kit project structure)"
metadata:
  author: "myspace-team"
user-invocable: true
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Overview

`/speckit-commit` is the conversational layer over `scripts/commit-workflow.sh` (`pnpm run commit`). The script does the deterministic work: staging inspection, scope and type heuristics, sensitive-file and credential detection, message validation, and the commit itself. You add judgement: reading the diff, choosing the type and writing the summary, asking the breaking-change question, and getting the contributor's confirmation. A human and an agent must get the same result.

Contract: `specs/003-standardize-commits/contracts/skill-contract.md`. Rules: `contracts/scope-and-type-rules.md` and `contracts/safety-rules.md`.

## Branch Guard

Run before any other step. Branch rules live in `.claude/hooks/branch_policy.py` and are enforced by a PreToolUse hook (hard block).

1. Get the current branch: `git branch --show-current`.
2. If it is `main`/`master`, or `python3 .claude/hooks/branch_policy.py "<branch>"` exits non-zero, **STOP** and use AskUserQuestion to ask the user for a branch name. Propose a name derived from the staged changes.
3. Create it with `git switch -c <name>` (staged changes carry over), re-validate with the script above, then continue.
4. Never create or rename a branch with a name that fails validation.

Rules: `<type>/<description>` or `<type>/<scope>/<description>` (type: feat, fix, chore, docs, refactor, test, ci, infra, req; scope optional), or the Spec Kit form `NNN-<description>`. Lowercase kebab-case, description 3-50 chars. Reserved: main, master, develop, HEAD, release/*.

## Pre-Commit Checklist

Do not run `commit` until every box is true:

- [ ] Branch guard passed (not on a protected branch)
- [ ] `propose` ran and every blocking finding was resolved or explicitly allowed by the user
- [ ] The message passes `validate` with no errors (warnings are informational)
- [ ] The exact final message was shown to the user
- [ ] The user explicitly confirmed that exact message in this turn

## Flow

1. **Propose**: run `bash scripts/commit-workflow.sh propose --json` and read the result.
   - `status: empty` (exit 2): tell the user nothing is staged and show `git add <paths>`. Stop. **Never stage files on the user's behalf.**
   - `status: blocked` (exit 3): list each finding (path and rule, never any secret text) and stop. Explain `--allow-sensitive <path>` only for deliberate cases such as the tracked `apps/idea-collector/frontend/.env`. If the user explicitly approves that specific path, re-run `propose --allow-sensitive <path>` and pass the same flag to `commit` later. Never suggest it for a `secret-pattern` finding; those cannot be overridden: unstage the file and rotate the secret.
   - `unstaged_count > 0`: mention that unstaged work exists and will not be committed.
   - `warnings` contains `multi-scope`: show `split_suggestion` and offer to split (`git restore --staged <files>`, run by the user or with their approval). Continue only if the user chooses to.
2. **Refine**: if `proposal.type` is null or there is no summary, read `git diff --cached` and pick the type from `type_candidates`, then write a concise imperative summary under 100 characters in the header. Types: feat, fix, chore, docs, style, refactor, perf, test, build, ci, req, infra. Do not invent facts the diff does not show.
3. **Breaking check**: if `breaking_hints` is non-empty, ask whether the change is breaking. If yes, collect what breaks (`--breaking "<text>"`); if no, use `--no-breaking`.
4. **Validate**: run `bash scripts/commit-workflow.sh validate "<message>"`. Fix every error and show warnings.
5. **Review**: show the full message and ask the user to confirm, edit, or cancel (use AskUserQuestion where available). A confirmation covers only the exact message shown; any edit voids it, so validate again and ask again. Do not continue without an explicit answer.
   - Cancel: stop. Nothing is committed and the staged files are untouched.
6. **Commit**: only after step 5 returned an explicit confirmation, run `bash scripts/commit-workflow.sh commit --message "<message>" --yes` with `[--breaking ...] [--no-breaking] [--allow-sensitive <path>] [--trailer "Co-Authored-By: ..."]`. Include the session's required attribution trailer if the environment mandates one.
7. **Report**: show the header and the returned short hash. On a non-zero exit, show the error and the remediation below.

For `--validate "<message>"` input, run only step 4 and explain the defects; do not commit.

## Failure mapping

| Exit | Meaning | What to do |
| :--- | :--- | :--- |
| 1 | Invalid message (at least one error) | List every issue with its severity and suggestion; warnings do not block; re-run after the edit |
| 2 | Nothing staged | `git add <paths>` guidance |
| 3 | Safety finding | Unstage or remove the file and rotate anything exposed; override only per sensitive path |
| 4 | Protected branch | Ask for a branch name, `git switch -c` |
| 5 | Missing confirmation | Ask the user, then retry with `--yes` |
| 6 | Breaking decision needed | Ask, then pass `--breaking` or `--no-breaking` |
| 7 | Git rejected the commit | Show git's output; do not retry with `--no-verify` |
| 64 | Usage error | Check the command and flags |

## Guarantees

- Commits only what is already staged; never runs `git add`, `-a`, `--amend` or `--no-verify`.
- Never commits without an explicit confirmation of the exact message. `--yes` is passed only after the user has seen that exact message and confirmed it in the current turn; never on your own initiative, in advance, or reused after an edit.
- Never prints a matched secret value.
- No edits to CI workflows or infra.
