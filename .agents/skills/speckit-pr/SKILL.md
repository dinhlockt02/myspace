---
name: "speckit-pr"
description: "Manage post-implementation Pull Request workflows: create draft PRs, update descriptions, run pre-flight quality checks, and monitor CI status."
compatibility: "Requires spec-kit project structure with git and GitHub access"
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
- `--base <branch>`: Target integration base branch (default: `main`).

## Overview

The `/speckit-pr` skill provides an interactive, conversational slash command companion for developers and AI pairing agents to manage post-implementation GitHub Pull Request workflows (and Merge Request aliases). It delegates to the underlying repository CLI (`./scripts/pr-workflow.sh`), enforces Monorepo Constitution Principle I & III, and formats responses with direct links to the created PR.

## Execution Steps

1. **Parse Arguments & Select Workflow**:
   - Inspect `$ARGUMENTS`.
   - Determine target command:
     - If `--status` or `status`: run status inspection.
     - If `--check` or `check`: run pre-flight check only.
     - If `--update` or `update`: run PR update.
     - If `--create` or `create`: run PR creation.
     - If empty: pass arguments to CLI for context-aware auto-detection (updates if PR exists, creates draft PR if not).

2. **Execute Core CLI**:
   - Run `bash scripts/pr-workflow.sh $ARGUMENTS --json`
   - Capture and parse the resulting JSON payload.

3. **Handle Outcomes**:
   - **On Success**:
     - **Created**: Present a formatted summary highlighting the PR number, Draft status, affected monorepo projects, and a clickable Markdown link to the PR URL.
     - **Updated**: Report that the PR description, completed task checklist, and reviewer notes were refreshed.
     - **Status**: Display a clean status table showing active GitHub Actions workflows, check conclusions, and mergeability.
     - **Checked**: Confirm that all quality gates (git cleanliness, linting, tests, secrets audit) passed.
   - **On Failure**:
     - Parse the error message and display actionable remediation:
       - *Dirty git tree*: Prompt the user to commit or stash uncommitted changes.
       - *Lint/Test failure*: Highlight the failing project test suite.
       - *Missing auth*: Provide instructions to run `gh auth login` or export `GITHUB_TOKEN`.
       - *Potential secrets detected*: Alert the developer to scrub credentials before pushing.

4. **Suggest Next Steps**:
   - Recommend next actions (e.g., `/speckit-pr --status` to monitor CI, or `/speckit-pr --ready` to publish for review).
