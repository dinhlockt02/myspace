# Developer Onboarding Guide

Welcome to **myspace**! This guide details the complete developer environment setup, backing container services, AI-native SDLC workflows, and self-service troubleshooting procedures.

---

## 1. Overview & Architecture

The repository provides a **dual-mode onboarding system**:
1. **Automated Root CLI Script** (`pnpm run setup` or `./scripts/setup-dev.sh`): Executes prerequisites detection, dependency bootstrapping, container lifecycle management, AI skill auditing, and smoke tests directly in your terminal.
2. **Companion AI Onboarding Skill** (`/dev-onboarding`): An interactive AI agent skill located at `.agents/skills/dev-onboarding/SKILL.md` that guides you step-by-step, diagnoses environment issues, and runs verification commands automatically.

Both modes share the same underlying logic, configuration templates, and diagnostic reporter.

---

## 2. Host Prerequisites

Before beginning, ensure your workstation meets the following minimum tool versions:

| Tool | Minimum Version | Recommended Installation |
| :--- | :--- | :--- |
| **Node.js** | `>= 20.0.0` | [nodejs.org](https://nodejs.org/) or via `nvm` / `fnm` |
| **pnpm** | `>= 9.0.0` | `corepack enable && corepack prepare pnpm@latest --activate` or `npm i -g pnpm` |
| **Go** | `>= 1.22.0` | [go.dev/dl](https://go.dev/dl/) or via package manager (`brew install go`, `apt install golang`) |
| **Docker Engine** | `>= 24.0.0` | [docs.docker.com/engine/install/](https://docs.docker.com/engine/install/) or Docker Desktop |
| **Docker Compose** | `>= 2.20.0` | Included with modern Docker CLI (`docker compose`) |

Supported operating systems: **Linux** (Ubuntu, Debian, Fedora, Arch), **macOS** (Apple Silicon & Intel), and **Windows WSL2**.

---

## 3. Quick Start (Fresh Clone to Ready-to-Code)

### Option A: Terminal CLI Setup (Fastest)

Run the full setup pipeline in a single command:

```bash
pnpm run setup
```
*(Alternatively: `./scripts/setup-dev.sh`)*

This command automatically:
1. Audits host tools and versions.
2. Installs monorepo dependencies (`pnpm install`).
3. Instantiates local environment templates (`.env.example` -> `.env`) with safe mock defaults.
4. Starts local backing service containers (DynamoDB Local on port `8000`).
5. Audits all repository AI skills and governance documents.
6. Runs workspace smoke tests (`lint`, `test`, `build`).
7. Generates a comprehensive summary and persists diagnostic reports to `.specify/reports/`.

### Option B: Interactive AI Agent Setup

If working inside an AI-assisted environment (e.g., Antigravity):
1. In your agent chat prompt, invoke the skill:
   ```text
   /dev-onboarding
   ```
2. The agent will inspect your workstation profile, execute prerequisite verifications, guide container initialization, and report operational status.

---

## 4. CLI Command Reference

The onboarding script supports granular lifecycle flags:

```bash
# Display help and usage information
./scripts/setup-dev.sh --help

# Non-destructive host prerequisite audit only (no files or containers modified)
pnpm run setup -- --check-only

# Output prerequisite diagnostic profile as JSON
./scripts/setup-dev.sh --check-only --json

# Bootstrap dependencies and instantiate .env templates only
pnpm run setup -- --bootstrap

# Provision and health-check local backing service containers only
pnpm run setup -- --containers

# Audit all 11 Spec-Kit skills and repository governance rules
pnpm run setup -- --verify-skills

# Run full end-to-end smoke test across all workspace applications
pnpm run setup -- --verify

# Clean build caches, node_modules, and container state before setup
pnpm run setup -- --clean
```

---

## 5. Backing Services & Local Containers

The repository uses container emulation to allow local development and testing without requiring cloud access or cloud credentials.

### Docker Compose Architecture
The local container configuration is defined in [`docker-compose.yml`](file:///home/loctran/code/myspace/docker-compose.yml):
- **Service**: `dynamodb-local` (`amazon/dynamodb-local:latest`)
- **Port**: `8000:8000`
- **Health Check**: Port probe testing readiness on port 8000
- **Arguments**: `-jar DynamoDBLocal.jar -sharedDb -inMemory` (ephemeral local storage)

### Container Lifecycle Commands
```bash
# Start backing services in background
docker compose up -d

# Check status and health of containers
docker compose ps

# View container logs
docker compose logs -f dynamodb-local

# Stop containers
docker compose down

# Stop and remove volumes
docker compose down -v
```

---

## 6. Configuration & Environment Templates

Per **Constitution Principle IV**, all local environments use functioning local mock/container defaults with **zero cloud credentials or secrets**.

The bootstrap process creates `.env` files from `.env.example` templates if `.env` does not already exist:

| Application | Path | Template | Key Variables |
| :--- | :--- | :--- | :--- |
| **Idea Collector Frontend** | `apps/idea-collector/frontend/.env` | `.env.example` | `VITE_API_URL=http://localhost:8080`<br>`VITE_APP_TITLE="Idea Collector (Local)"` |
| **Idea Collector Backend** | `apps/idea-collector/backend/.env` | `.env.example` | `PORT=8080`<br>`DYNAMODB_ENDPOINT=http://localhost:8000`<br>`AWS_REGION=local`<br>`AWS_ACCESS_KEY_ID=mock-local-key`<br>`AWS_SECRET_ACCESS_KEY=mock-local-secret` |

> [!NOTE]
> Existing `.env` files are **never overwritten** by the setup script. If you need to regenerate defaults, delete or rename your current `.env` and rerun `pnpm run setup -- --bootstrap`.

---

## 7. AI Skills & Governance Cheat-Sheet

The repository operates an autonomous, AI-native SDLC pipeline. All skills are located under `.agents/skills/`:

### Spec-Kit Lifecycle Workflow
| Skill / Command | Description |
| :--- | :--- |
| `/dev-onboarding` | Interactive developer onboarding and environment diagnostics |
| `/speckit-constitution` | Create or update project governance principles and rules |
| `/speckit-specify` | Create or update feature specification (`spec.md`) from user requirements |
| `/speckit-clarify` | Identify ambiguous areas and ask targeted clarification questions |
| `/speckit-checklist` | Generate custom quality checklists for feature requirements |
| `/speckit-plan` | Generate architectural plans, schemas, and quickstart guides (`plan.md`) |
| `/speckit-tasks` | Break down implementation plans into dependency-ordered tasks (`tasks.md`) |
| `/speckit-taskstoissues`| Convert implementation tasks into GitHub issues |
| `/speckit-implement` | Autonomously execute and check off tasks defined in `tasks.md` |
| `/speckit-converge` | Validate codebase against specification and append remaining work |
| `/speckit-analyze` | Cross-artifact consistency and quality analysis |
| `/speckit-pr` | Post-implementation Pull Request creation, synchronization, status, and pre-flight quality checks |

### Governance Rules
- [`AGENTS.md`](file:///home/loctran/code/myspace/AGENTS.md): Repository structure, AI constraints, CI/CD, and infra conventions.
- [`.specify/memory/constitution.md`](file:///home/loctran/code/myspace/.specify/memory/constitution.md): Core architectural principles (Specification-First, Autonomous Agents, Test Automation, Zero Secrets).

---

## 8. Self-Service Troubleshooting

### Issue 1: Docker Daemon Not Running
**Symptoms:**
```text
Cannot connect to the Docker daemon at unix:///var/run/docker.sock. Is the docker daemon running?
```
**Resolution:**
- **Linux:** Start the system service:
  ```bash
  sudo systemctl start docker
  sudo systemctl enable docker
  ```
- **macOS / Windows WSL2:** Launch Docker Desktop from your applications menu and ensure the engine status indicates "Running".

### Issue 2: Docker Socket Permission Denied
**Symptoms:**
```text
permission denied while trying to connect to the Docker daemon socket
```
**Resolution:**
Add your current user to the `docker` user group and refresh the active session:
```bash
sudo usermod -aG docker $USER
newgrp docker
```

### Issue 3: Port 8000 Collision (DynamoDB Local)
**Symptoms:**
```text
Bind for 0.0.0.0:8000 failed: port is already allocated
```
**Resolution:**
1. Identify the process or container holding port 8000:
   ```bash
   lsof -i :8000
   # or
   docker ps --filter "publish=8000"
   ```
2. Stop the conflicting container or process:
   ```bash
   docker stop <container-id>
   ```
3. Retry container startup:
   ```bash
   pnpm run setup -- --containers
   ```

### Issue 4: Script Permission Denied
**Symptoms:**
```text
bash: ./scripts/setup-dev.sh: Permission denied
```
**Resolution:**
Ensure execution permissions are granted across all setup scripts:
```bash
chmod +x scripts/setup-dev.sh scripts/lib/*.sh
```

### Issue 5: Stale Caches or Broken `node_modules`
**Symptoms:**
Unexpected build or typecheck failures due to stale cache files or outdated dependencies.
**Resolution:**
Execute a clean reset using the `--clean` flag:
```bash
pnpm run setup -- --clean
```
This purges `node_modules`, `.nx/cache`, and temporary build artifacts before reinstalling dependencies cleanly.

### Issue 6: Nx Daemon Failure in Subshells or Sandboxes
**Symptoms:**
```text
Failed to start plugin worker or daemon connection failed
```
**Resolution:**
Disable Nx daemon for the current terminal session:
```bash
export NX_DAEMON=false
```

---

## 9. Diagnostic Reports & Audit Artifacts

Every execution of `./scripts/setup-dev.sh` records detailed diagnostic information:
- **Human-Readable Summary**: `.specify/reports/latest-onboarding.md`
- **Machine-Readable JSON**: `.specify/reports/onboarding-<timestamp>.json`

These files are ignored by git to keep your repository history clean. You can inspect the latest diagnostic report at any time:
```bash
cat .specify/reports/latest-onboarding.md
```
