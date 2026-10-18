---
name: "speckit-pr"
description: "Manage post-implementation Pull Request workflows: create draft PRs, update descriptions with deployment notes, run pre-flight quality checks, and monitor CI status."
compatibility: "Requires spec-kit project structure with git and GitHub CLI (gh)"
metadata:
  author: "myspace-team"
---

## User Input

```text
$ARGUMENTS
```

Optional arguments & flags accepted:
- `--create`, `create`, `create-mr`: Create a new GitHub Pull Request.
- `--update`, `update`, `update-mr`: Update an existing open Pull Request's description and task progress.
- `--status`, `status`, `checks`: Query GitHub Actions CI check run statuses and merge readiness.
- `--check`, `check`, `verify`: Run pre-flight quality gates locally without remote changes.
- `--draft`: Create Pull Request in Draft mode (default).
- `--ready`, `--publish`: Create or mark Pull Request as Ready for Review.
- `--notes <text>`: Append custom reviewer notes during update.
- `--deploy-notes <text>`, `--deployment-notes <text>`: Append custom deployment notes or operational instructions.
- `--base <branch>`: Target integration base branch (default: `main`).

## Overview

The `/speckit-pr` skill provides an interactive, conversational slash command companion for developers and AI pairing agents to manage post-implementation GitHub Pull Request workflows (and Merge Request aliases). It delegates to the underlying repository CLI (`./scripts/pr-workflow.sh`), enforces Monorepo Constitution Principle I, II & III (Intent, Scope, Verification Steps, Deployment Notes, Pre-Flight Gates), and formats responses with direct links to the created PR.

## Branch Guard

Run before any other step. Branch rules live in `.claude/hooks/branch_policy.py` and are enforced by a PreToolUse hook (hard block).

1. Get the current branch: `git branch --show-current`.
2. If it is `main`/`master`, or `python3 .claude/hooks/branch_policy.py "<branch>"` exits non-zero, **STOP** and use AskUserQuestion to ask the user for a branch name. Propose a name derived from the current work; the PR is opened from this branch.
3. Create it with `git switch -c <name>` (uncommitted changes carry over), re-validate with the script above, then continue.
4. Never create or rename a branch with a name that fails validation.

Rules: `<type>/<description>` or `<type>/<scope>/<description>` (type: feat, fix, chore, docs, refactor, test, ci, infra, req; scope optional), or the Spec Kit form `NNN-<description>`. Lowercase kebab-case, description 3-50 chars. Reserved: main, master, develop, HEAD, release/*.

## Execution Steps

1. **Prerequisite Check (Require GitHub CLI `gh`)**:
   - Unless running local quality gates exclusively (`--check`), the agent MUST verify that the GitHub CLI (`gh`) is installed and authenticated BEFORE proceeding:
     - Check installation: Run `command -v gh`.
     - Check authentication: Run `gh auth status`.
   - **If `gh` is missing or unauthenticated, HALT IMMEDIATELY**:
     - Do not run test gates, do not push branches to remote, and do not invoke `pr-workflow.sh`.
     - Present clear diagnostic instructions to the user:
       - *Missing `gh`*: Instruct them to install GitHub CLI from https://cli.github.com/ or via `sudo apt install gh` / `brew install gh`.
       - *Unauthenticated `gh`*: Instruct them to run `gh auth login` in their terminal to authenticate with GitHub.
     - Prompt the user to re-run `/speckit-pr` once logged in.

2. **Parse Arguments & Select Workflow**:
   - Inspect `$ARGUMENTS`.
   - Determine target command:
     - If `--status` or `status`: run status inspection.
     - If `--check` or `check`: run pre-flight check only.
     - If `--update` or `update`: run PR update.
     - If `--create` or `create`: run PR creation.
     - If empty: pass arguments to CLI for context-aware auto-detection (updates if PR exists, creates draft PR if not).

3. **Execute Core CLI**:
   - Run `bash scripts/pr-workflow.sh $ARGUMENTS --json`
   - Capture and parse the resulting JSON payload.

4. **Handle Outcomes**:
   - **On Success**:
     - **Created**: Present a formatted summary highlighting the PR number, Draft status, affected monorepo projects, and a clickable Markdown link to the PR URL.
     - **Updated**: Report that the PR description, completed task checklist, reviewer notes, and deployment notes were refreshed.
     - **Status**: Display a clean status table showing active GitHub Actions workflows, check conclusions, and mergeability.
     - **Checked**: Confirm that all quality gates (git cleanliness, linting, tests, secrets audit) passed.
   - **On Failure**:
     - Parse the error message and display actionable remediation:
       - *Missing auth*: Provide instructions to run `gh auth login` or export `GITHUB_TOKEN`.
       - *Dirty git tree*: Prompt the user to commit or stash uncommitted changes.
       - *Lint/Test failure*: Highlight the failing project test suite.
       - *Potential secrets detected*: Alert the developer to scrub credentials before pushing.

5. **Suggest Next Steps**:
   - Recommend next actions (e.g., `/speckit-pr --status` to monitor CI, or `/speckit-pr --ready` to publish for review).
