# AI Skill Contract: `/dev-onboarding`

This document defines the agent interaction contract for the developer onboarding companion skill.

## Skill Metadata

- **Name**: `dev-onboarding`
- **Location**: `.agents/skills/dev-onboarding/SKILL.md`
- **Trigger**: `/dev-onboarding [optional args: --check-only | --verify | --clean]`

## Invocation Protocol

### Inputs

```text
$ARGUMENTS
```
Optional flags passed by the user:
- Empty: Executes standard interactive onboarding (prerequisites -> bootstrap -> containers -> skills audit -> smoke test).
- `--check-only`: Executes non-destructive health checks and audits.
- `--verify`: Executes smoke tests across workspace applications.
- `--clean`: Purges caches and containers before fresh setup.

### Operational Sequence

1. **Host Assessment**: The agent executes `scripts/setup-dev.sh --check-only --json`.
   - If prerequisites fail: The agent analyzes the returned JSON `remediation_steps`, presents them to the developer conversationally, and provides copy-pasteable commands for their OS.
2. **Bootstrap & Containers**: If checks pass, the agent triggers `scripts/setup-dev.sh --bootstrap --containers --json`.
   - The agent monitors progress, verifies that DynamoDB Local container starts, and verifies `.env` template instantiation.
3. **AI Skills Audit**: The agent audits `.agents/skills/` against all Spec-Kit and commit standardization skills.
4. **Smoke Test & Completion Report**: The agent runs `scripts/setup-dev.sh --verify --json` and formats a human-friendly completion summary linking to the persisted report in `.specify/reports/latest-onboarding.md`.

### Error Handling & Guardrails

- The skill must never commit credentials or edit `.env` with real secrets.
- The skill must check for root/sudo barriers and avoid running `sudo` directly.
- The skill must offer targeted retry if individual steps (e.g., container pull timeout) fail.
