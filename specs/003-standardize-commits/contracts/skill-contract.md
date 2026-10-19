# Skill Contract: `/speckit-commit`

**Feature**: `003-standardize-commits`
**Files**: `.agents/skills/speckit-commit/SKILL.md`, copied to `.claude/skills/speckit-commit/SKILL.md`

## Overview

`/speckit-commit` is the conversational layer over `scripts/commit-workflow.sh`. It turns the staged changes into a validated Conventional Commits message, asks for confirmation, and commits. It must give the same result for a human and for an agent (FR-010).

## Invocation

```text
/speckit-commit [message hint | --validate "<message>" | --breaking "<text>"]
```

| Input | Behaviour |
| :--- | :--- |
| *(empty)* | Propose from the staged set, review, commit |
| Free text | Treated as a hint for the summary or intent |
| `--validate "<message>"` | Only validate and explain defects; do not commit |
| `--breaking "<text>"` | Pre-answers the breaking-change question |

## Flow

1. **Branch guard**: run `git branch --show-current`. If it is `main`/`master`, stop and ask the user for a branch name that satisfies `.claude/hooks/branch_policy.py`, then `git switch -c <name>`.
2. **Propose**: run `bash scripts/commit-workflow.sh propose --json` and read the result.
   - `status: empty` (exit 2): tell the user nothing is staged and show how to stage (`git add <paths>`); stop. Never stage on the user's behalf.
   - `status: blocked` (exit 3): list each finding (path and rule, never the secret text), and stop. Explain the `--allow-sensitive <path>` override only for deliberate cases such as the tracked `apps/idea-collector/frontend/.env`; if the user explicitly approves that specific path, re-run `propose --allow-sensitive <path>` and pass the same flag to `commit` later. Never suggest it for a credential-content finding, which cannot be overridden.
   - `unstaged_count > 0`: mention that unstaged work exists and will not be committed.
   - `warnings` containing `multi-scope`: show `split_suggestion` and offer to split; continue only if the user chooses to.
3. **Refine**: if `type` is null or the summary is empty, read `git diff --cached` and choose the type from `type_candidates`, then write a concise imperative summary. Do not invent facts the diff does not show.
4. **Breaking check**: if `breaking_hints` is non-empty, ask whether the change is breaking. If yes, collect the explanation.
5. **Review**: show the full message and ask the user to confirm, edit, or cancel (use the interactive question tool where available).
   - Edit: apply the change, run `validate`, show the result (errors block; warnings are informational), and ask again. A confirmation applies only to the exact message that was shown, so any edit voids it.
   - Do not continue without an explicit answer to this question.
   - Cancel: stop. The index is untouched; nothing is committed.
6. **Commit**: only after step 5 returned an explicit confirmation of the exact final message, run `bash scripts/commit-workflow.sh commit --message "<message>" --yes [--breaking ...] [--trailer "Co-Authored-By: ..."]`. Include the session's required attribution trailer if the environment mandates one.
7. **Report**: print the header and the returned short hash. On a non-zero exit, show the error and the remediation from the table below.

## Failure mapping

| Exit | Meaning | Remediation shown |
| :--- | :--- | :--- |
| 1 | Invalid message (at least one error-level issue) | List every issue with its severity and suggestion; warnings do not block; re-run after edit |
| 2 | Nothing staged | `git add <paths>` guidance |
| 3 | Safety finding | Unstage or remove the file, rotate anything exposed; override only per path |
| 4 | Protected branch | Ask for a branch name, `git switch -c` |
| 5 | Missing confirmation | Ask the user, then retry with `--yes` |
| 6 | Breaking decision needed | Ask, then pass `--breaking` or `--no-breaking` |
| 7 | Git rejected the commit | Show git's output; do not retry with `--no-verify` |

## Guarantees

- Commits only what is already staged; never runs `git add`, `-a`, `--amend` or `--no-verify`.
- Never commits without an explicit confirmation of the exact message. `--yes` is passed only after the user has seen that exact message and confirmed it in the current turn; it is never passed on the skill's own initiative, in advance, or reused after an edit.
- Never prints a matched secret value.
- No edits to CI workflows or infra.
