# Quickstart & Validation Guide: Post-Implementation PR Management Skills

**Feature**: `007-manage-pr-workflow`
**Date**: 2026-10-12
**Status**: Ready for Validation

This guide provides runnable scenarios to validate the post-implementation Pull Request workflow end-to-end across CLI and AI companion skill interfaces.

---

## Prerequisites

1. **Host Environment**:
   - Git configured with an active branch
   - Working internet connectivity
   - GitHub authentication via either:
     - `gh auth status` (GitHub CLI), OR
     - `export GITHUB_TOKEN="<your-personal-access-token>"`
2. **Repository Baseline**:
   - Monorepo dependencies installed: `pnpm install`

---

## Validation Scenarios

### Scenario 1: Pre-Flight Check on Clean Workspace (PASS)

Tests that the pre-flight gate correctly validates git status, lint, and test suites without creating any remote resources.

```bash
# Execute pre-flight verification only
bash scripts/pr-workflow.sh check --json
```

**Expected Outcome**:
- Exit code: `0`
- JSON output includes `"status": "success"`, `"action": "checked"`, and all quality gates reported as `true`.

---

### Scenario 2: Pre-Flight Check Blocks on Dirty Working Tree (FAIL-SAFE)

Tests that uncommitted files are detected and prevent accidental or incomplete PR submissions.

```bash
# 1. Create a temporary untracked file
touch temp-dirty-test-file.txt

# 2. Attempt pre-flight check
bash scripts/pr-workflow.sh check

# 3. Clean up temporary file
rm -f temp-dirty-test-file.txt
```

**Expected Outcome**:
- Exit code: `1`
- Console error alerting that uncommitted changes exist on the working tree.
- Workflow halts immediately before any remote calls.

---

### Scenario 3: Create Draft Pull Request via CLI

Tests that `scripts/pr-workflow.sh create` publishes a Draft Pull Request to GitHub with full constitutional metadata.

```bash
# Open Draft Pull Request with JSON output
bash scripts/pr-workflow.sh create --draft --json
```

**Expected Outcome**:
- Exit code: `0`
- Branch pushed to `origin/<branch>` if not already up to date.
- Draft Pull Request created on GitHub.
- Output JSON contains valid `pr_number`, `pr_url`, and `is_draft: true`.
- PR description contains sections: Intent, Scope, Completed Tasks, Verification Steps, and Pre-Flight Quality Gates.

---

### Scenario 4: Synchronize & Update Existing Pull Request

Tests that making an additional commit and running `update` refreshes the PR body while preserving existing comments.

```bash
# 1. Refresh existing PR
bash scripts/pr-workflow.sh update --notes "Applied reviewer feedback on pre-flight checks" --json
```

**Expected Outcome**:
- Exit code: `0`
- PR title and body refreshed on GitHub.
- Task checklist updated.
- Existing PR number and review comments remain intact.

---

### Scenario 5: Inspect Pull Request Status & CI Checks

Tests that `status` queries GitHub Actions checks and reports merge readiness.

```bash
# Query PR check status
bash scripts/pr-workflow.sh status --json
```

**Expected Outcome**:
- Exit code: `0`
- Outputs table/JSON of active or completed GitHub Actions workflow runs and mergeability state.

---

### Scenario 6: Conversational Execution via `/speckit-pr` Agent Skill

Tests the interactive developer experience using Antigravity AI skills:

1. In the agent prompt, invoke:
   ```text
   /speckit-pr
   ```
2. The agent executes `scripts/pr-workflow.sh` with auto-detection, verifies quality gates, and outputs a formatted summary with clickable links to the PR.

---

### Scenario 7: Onboarding & Skills Audit Verification

Tests that the developer onboarding suite (`/dev-onboarding` and `scripts/setup-dev.sh --verify-skills`) detects and verifies `/speckit-pr` alongside the other repository SDLC skills.

```bash
# Verify skills audit includes speckit-pr
bash scripts/setup-dev.sh --verify-skills --json
```

**Expected Outcome**:
- Exit code: `0`
- Skills JSON array includes `{"skill_name":"speckit-pr", "status":"operational", "manifest_valid":true}`
- Total verified skills reported increases to 11 operational skills.
