# Research & Decisions: Developer Environment Onboarding and AI Skills Setup

## 1. Onboarding Toolchain and Execution Architecture

**Task**: Research the optimal execution architecture for the root developer setup workflow in a multi-language monorepo (Node.js/TypeScript, Go, Terraform) supporting both standalone terminal execution and AI agent orchestration.

**Decision**: Implement a modular shell script at `scripts/setup-dev.sh` integrated with `package.json` via `pnpm run setup`, supported by sub-commands/flags:
- `--check-only`: Runs prerequisite and environment diagnostics without modifying files.
- `--bootstrap`: Installs monorepo dependencies and generates environment files.
- `--containers`: Provisions and health-checks local Docker Compose services.
- `--verify`: Runs the complete end-to-end smoke test suite across all projects.
- `--clean`: Purges node_modules, build caches, and stale container volumes before setup.
- `--json`: Outputs machine-readable diagnostic output for AI agent consumption.

**Rationale**:
- Shell scripts (`bash`) execute natively on Linux, macOS, and Windows (WSL) without requiring prior dependency installation, solving the "chicken-and-egg" bootstrapping problem (Node/pnpm cannot be assumed to have packages installed before running setup).
- Wiring to `package.json` (`pnpm run setup`) provides intuitive, standard ergonomics for developers accustomed to npm/pnpm scripts.
- Flag-based separation allows the companion AI agent skill to invoke specific phases independently (e.g., re-running only container health or prerequisite check during troubleshooting).

**Alternatives considered**:
- Pure Node.js script (e.g., `tsx scripts/setup.ts`): Rejected because it requires `node` and `pnpm install` before it can execute, failing when a new developer has missing or broken packages.
- Make / Makefile: Viable, but standardizing on Bash scripts with `pnpm` entry points provides better platform portability across monorepo developers and consistent error handling.

---

## 2. Local Containerized Backing Services Architecture (Docker Compose)

**Task**: Research the local containerization strategy for backing services (specifically AWS DynamoDB for `idea-collector`) to satisfy the Mandatory Container Emulation decision without requiring external cloud accounts.

**Decision**: Introduce a root `docker-compose.yml` declaring `dynamodb-local` (using official `amazon/dynamodb-local:latest`) mapped to host port `8000`, equipped with an automated Docker healthcheck (`curl` or socket probe). Provide a lifecycle helper script (`scripts/services.sh` or within `setup-dev.sh`) to start, stop, and verify container readiness.

**Rationale**:
- `amazon/dynamodb-local` is the official, high-fidelity emulator for DynamoDB.
- Any AWS SDK or CLI client can target `http://localhost:8000` with dummy credentials (`AWS_ACCESS_KEY_ID=local`, `AWS_SECRET_ACCESS_KEY=local`, `AWS_REGION=us-east-1`).
- Eliminates cloud dependency while matching production DynamoDB schema and API semantics.
- Healthcheck guarantees that backend services wait until DynamoDB Local is accepting TCP connections before smoke tests execute.

**Alternatives considered**:
- LocalStack container: Provides full AWS suite, but is significantly heavier in memory (1GB+) and slower to start. DynamoDB Local is lightweight (<100MB), starts in under 2 seconds, and satisfies all current monorepo database needs.
- In-memory mock adapter only: Disallowed by accepted clarification Q3 (Mandatory Container Emulation).

---

## 3. Environment Configuration & Secret Safety (.env.example Strategy)

**Task**: Research safe, automated local configuration generation that prevents credential leakage and satisfies Myspace Constitution Principle IV (Strict Security & Credential Handling).

**Decision**: Provide structured `.env.example` templates in every application (`apps/idea-collector/frontend/.env.example`, `apps/idea-collector/backend/.env.example`) populated with functional local container and mock defaults:
- Frontend: `VITE_API_URL=http://localhost:8080`, `VITE_STAGE=local`
- Backend: `PORT=8080`, `DYNAMODB_ENDPOINT=http://localhost:8000`, `AWS_REGION=us-east-1`, `AWS_ACCESS_KEY_ID=local`, `AWS_SECRET_ACCESS_KEY=local`, `TABLE_NAME=IdeaCollector_Ideas_local`
The setup script copies `.env.example` to `.env` if `.env` does not already exist, preserving any existing developer customizations. Target `.env` files are verified in `.gitignore`.

**Rationale**:
- Completely zero-credential requirement for day-one local development and tests.
- Complies strictly with Constitution Principle IV (no real secrets or credentials in repo).
- Idempotent: re-running setup never overwrites a developer's existing customized `.env`.

**Alternatives considered**:
- Interactive CLI prompt for keys: Disallowed by accepted clarification Q2 (Local/Mock Defaults).
- Committed `.env`: Violates security best practices and monorepo constitution.

---

## 4. AI Skill Implementation & Verification Protocol

**Task**: Research how to package the companion onboarding skill and audit all repository AI skills across the complete AI-native SDLC suite.

**Decision**:
1. Implement `.agents/skills/dev-onboarding/SKILL.md` exposing the `/dev-onboarding` skill command.
2. The skill orchestrates `scripts/setup-dev.sh`, parses diagnostic JSON outputs, diagnoses prerequisite failures interactively, and verifies active AI capabilities.
3. The verification protocol inspects `.agents/skills/` to ensure all 10 Spec-Kit skills (`speckit-specify`, `speckit-clarify`, `speckit-plan`, `speckit-tasks`, `speckit-implement`, `speckit-converge`, `speckit-analyze`, `speckit-checklist`, `speckit-taskstoissues`, `speckit-constitution`), commit rules, and `.specify/memory/constitution.md` are present, parseable, and syntactically valid.

**Rationale**:
- Satisfies accepted clarification Q1 (Hybrid approach) and Q4 (Complete AI-native SDLC suite audit).
- Provides conversational assistance when a developer's machine has missing tools (e.g., provides OS-specific install commands for Docker or Node.js).

**Alternatives considered**:
- Verification of core Spec-Kit skills only: Rejected by accepted clarification Q4.
- Hardcoded skill registry: Dynamically scanning `.agents/skills/` ensures new skills added in future tasks are automatically included in health audits.

---

## 5. Diagnostic Artifact Persistence Schema

**Task**: Research location and structure for persistent onboarding diagnostic records.

**Decision**: Persist diagnostic reports in `.specify/reports/` (gitignored, ensuring clean repository tree):
- Timestamped JSON report: `.specify/reports/onboarding-<YYYYMMDD-HHMMSS>.json`
- Latest human-readable Markdown summary: `.specify/reports/latest-onboarding.md`
- Terminal / Agent output: Formatted ANSI/markdown summary printed to stdout.

**Rationale**:
- Satisfies accepted clarification Q5 (Console output + Local workspace artifact).
- Machine-parseable JSON enables the AI onboarding skill and future agent commands to query environment status programmatically.
- Markdown summary allows human developers to inspect results or paste into support channels.
- Keeping reports in `.specify/reports/` aligns with existing Spec-Kit metadata conventions.

**Alternatives considered**:
- Ephemeral stdout only: Rejected by accepted clarification Q5.
- Committing reports to git: Rejected to prevent repository history clutter and personal workstation metadata leakage.
