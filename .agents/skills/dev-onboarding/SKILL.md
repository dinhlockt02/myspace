---
name: "dev-onboarding"
description: "Guide new developers through environment onboarding, host prerequisites validation, container initialization, and AI skills health checks."
compatibility: "Requires Myspace monorepo structure"
metadata:
  author: "myspace-team"
---

## User Input

```text
$ARGUMENTS
```

Optional arguments accepted:
- `--check-only`: Perform host diagnostic and prerequisites validation only.
- `--verify`: Run workspace smoke tests and report generation.
- `--clean`: Purge local caches and containers before fresh bootstrap.

## Overview

The `/dev-onboarding` skill provides an interactive, conversational companion for new developers onboarding onto the Myspace monorepo. It orchestrates the underlying CLI tool (`./scripts/setup-dev.sh`), parses machine-readable diagnostics, guides remediation for missing prerequisites, and verifies repository AI skills.

## Execution Steps

1. **Host Assessment & Prerequisites Check**:
   - Run `bash scripts/setup-dev.sh --check-only --json`
   - Parse the JSON profile output.
   - If `is_compatible` is `false`:
     - Display a clear table of detected tool versions.
     - Present the `remediation_steps` to the developer conversationally, providing copy-pasteable commands suited for their detected OS (`linux`, `darwin`, or `windows_wsl`).
     - Stop and allow the developer to install missing dependencies before proceeding.

2. **Workspace Bootstrap & Local Containers**:
   - If prerequisites are satisfied (or user requested full onboarding):
     - Execute `bash scripts/setup-dev.sh --bootstrap --containers --json`
     - Verify that pnpm dependencies are resolved and linked across workspaces.
     - Verify that `.env` files are generated from templates with working local/mock defaults.
     - Confirm that `dynamodb-local` container is running and healthy on port 8000.

3. **AI-Native SDLC Suite Audit**:
   - Execute `bash scripts/setup-dev.sh --verify-skills --json`
   - Audit all 11 Spec-Kit skills (including post-implementation `/speckit-pr`) and governance rules in `AGENTS.md` and `.specify/memory/constitution.md`.
   - Report active capabilities to the developer.

4. **Smoke Test & Verification**:
   - Execute `bash scripts/setup-dev.sh --verify --json`
   - Confirm compilation, linting, and baseline test execution across monorepo projects.

5. **Completion Summary**:
   - Present a concise onboarding summary:
     - Workstation compatibility status.
     - Active containerized services (`dynamodb-local` at http://localhost:8000).
     - Verified AI skills ready for pairing.
     - Link to persisted report in `.specify/reports/latest-onboarding.md`.
     - Recommend next steps (e.g., exploring `docs/ONBOARDING.md` or picking up a feature specification).
