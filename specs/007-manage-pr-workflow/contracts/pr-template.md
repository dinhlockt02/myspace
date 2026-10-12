# Contract: Generated Pull Request Markdown Body Format

**Feature**: `007-manage-pr-workflow`
**Standard**: Myspace Monorepo Constitution (Principle I & Principle III)

## Body Structure Specification

Every Pull Request generated or updated by `pr-workflow.sh` MUST adhere to the following Markdown template structure:

```markdown
## 🎯 Intent

[Concise, 1-3 sentence summary of the business intent and user value extracted from the feature specification.]

---

## 🔍 Scope & Touched Projects

- **Feature ID**: `{{FEATURE_ID}}`
- **Specification**: [`specs/{{FEATURE_ID}}/spec.md`](specs/{{FEATURE_ID}}/spec.md)
- **Affected Monorepo Projects**:
  - `{{PROJECT_1}}`
  - `{{PROJECT_2}}`

---

## ✅ Completed Tasks

<!-- Completed items extracted dynamically from specs/{{FEATURE_ID}}/tasks.md -->
- [x] {{TASK_1_SUMMARY}}
- [x] {{TASK_2_SUMMARY}}
- [x] {{TASK_3_SUMMARY}}

---

## 🧪 Verification Steps

Reviewers can verify this change by running the following commands locally:

1. **Host Verification**:
   ```bash
   pnpm run setup -- --check-only
   ```
2. **Project Smoke Tests & Builds**:
   ```bash
   pnpm nx run-many -t lint,test,build --projects={{AFFECTED_PROJECTS}}
   ```
3. **Feature-Specific Validation**:
   ```bash
   {{FEATURE_VALIDATION_COMMAND}}
   ```

---

## 🛡️ Pre-Flight Quality Gates

- [x] **Git Cleanliness**: No uncommitted or untracked changes
- [x] **Linting & Typecheck**: Clean pass across all affected packages
- [x] **Test Suites**: Unit and integration tests passing
- [x] **Secret Audit**: Diff verified free of credentials, tokens, and private keys

---

<!-- custom-notes -->
<!-- Reviewers: Add custom manual notes or context above this comment -->
```

## Structural Invariants

1. **Non-Empty Intent**: Intent section must contain human-readable prose explaining what and why.
2. **Explicit Scope**: Touched projects must be derived directly from modified file paths.
3. **Actionable Verification Steps**: Commands must be runnable by reviewers.
4. **Preservation Anchor**: The `<!-- custom-notes -->` comment is an immutable anchor allowing human reviewers to append persistent notes that survive automatic `--update` executions.
