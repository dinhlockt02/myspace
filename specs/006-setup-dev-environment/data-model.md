# Data Model: Developer Environment Onboarding and AI Skills Setup

This document defines the core domain entities, attributes, relationships, and validation rules for the developer environment onboarding and AI skills setup system.

## Entities

### 1. Developer Environment Profile

Represents the developer's workstation configuration detected during the assessment phase.

#### Attributes

| Attribute Name | Type | Description | Required | Validation / Constraints |
|----------------|------|-------------|----------|--------------------------|
| `os_type` | String | Operating system family | Yes | One of: `linux`, `darwin`, `windows_wsl` |
| `os_version` | String | OS release string | Yes | Non-empty |
| `shell` | String | Active terminal shell | Yes | e.g., `/bin/bash`, `/bin/zsh` |
| `node_version` | String | Detected Node.js runtime version | Yes | Semantic version, Minimum: `>= 20.0.0` |
| `pnpm_version` | String | Detected pnpm package manager version | Yes | Semantic version, Minimum: `>= 9.0.0` |
| `go_version` | String | Detected Go compiler version | Yes | Semantic version, Minimum: `>= 1.22.0` |
| `docker_version` | String | Detected Docker engine version | Yes | Semantic version, Minimum: `>= 24.0.0` |
| `compose_version` | String | Detected Docker Compose version | Yes | Semantic version, Minimum: `>= 2.20.0` |
| `docker_daemon_active` | Boolean | Whether Docker daemon is responsive | Yes | Must be `true` to pass assessment |
| `is_compatible` | Boolean | Aggregate host compatibility status | Yes | `true` only if all version gates pass |

---

### 2. Service Container State

Represents the lifecycle and runtime health of local backing service containers managed via Docker Compose.

#### Attributes

| Attribute Name | Type | Description | Required | Validation / Constraints |
|----------------|------|-------------|----------|--------------------------|
| `service_name` | String | Compose service identifier | Yes | e.g., `dynamodb-local` |
| `container_id` | String | Docker container hash | No | Populated when running |
| `image` | String | Container image tag | Yes | e.g., `amazon/dynamodb-local:latest` |
| `port_mapping` | String | Host to container port mapping | Yes | e.g., `8000:8000` |
| `status` | String | Runtime container status | Yes | One of: `running`, `stopped`, `exited`, `missing` |
| `health_status` | String | Health probe status | Yes | One of: `healthy`, `unhealthy`, `starting`, `none` |
| `endpoint_url` | String | Accessible local endpoint URL | Yes | e.g., `http://localhost:8000` |

---

### 3. Skill Verification Record

Represents the verification result of a registered repository AI skill or governance rule.

#### Attributes

| Attribute Name | Type | Description | Required | Validation / Constraints |
|----------------|------|-------------|----------|--------------------------|
| `skill_name` | String | Unique skill identifier | Yes | e.g., `speckit-specify`, `speckit-plan` |
| `skill_path` | String | Directory path relative to repo root | Yes | e.g., `.agents/skills/speckit-specify` |
| `manifest_valid` | Boolean | Whether skill frontmatter/manifest is valid | Yes | Must have valid YAML frontmatter |
| `instruction_valid` | Boolean | Whether instructions file exists and is readable | Yes | Must have valid markdown content |
| `status` | String | Verification operational status | Yes | One of: `operational`, `degraded`, `missing` |
| `error_message` | String | Specific error or warning message | No | Populated if degraded/missing |

---

### 4. Onboarding Diagnostic Report

Represents the overall outcome of an onboarding or health check run, persisted to `.specify/reports/`.

#### Attributes

| Attribute Name | Type | Description | Required | Validation / Constraints |
|----------------|------|-------------|----------|--------------------------|
| `id` | String | Unique run identifier | Yes | UUID or timestamp format `YYYYMMDD-HHMMSS` |
| `timestamp` | String | ISO 8601 execution timestamp | Yes | Valid ISO 8601 string |
| `mode` | String | Execution mode | Yes | One of: `check-only`, `full-setup`, `verify-only` |
| `overall_status` | String | Composite health verdict | Yes | One of: `passed`, `failed`, `warning` |
| `profile` | Object | Embedded `Developer Environment Profile` | Yes | Valid profile object |
| `containers` | Array | List of `Service Container State` records | Yes | Array of container records |
| `skills` | Array | List of `Skill Verification Record` records | Yes | Array of skill records |
| `smoke_test_results` | Object | Results of compilation, lint, and test passes | Yes | Sub-results per monorepo project |
| `remediation_steps` | Array | List of actionable steps to fix any issues | Yes | Array of human-readable action strings |

## State Transitions

### Onboarding Workflow Lifecycle

```
[ Uninitialized Clone ]
         │
         ▼
[ Host Assessment ] ────(Missing Prerequisite)───► [ Prerequisite Blocked ]
         │                                                    │
    (All Passed)                                          (Remediated)
         │                                                    │
         ▼                                                    ▼
[ Dependency Bootstrap & Config Init ] ◄──────────────────────┘
         │
    (Deps Installed & .env generated)
         │
         ▼
[ Local Container Provisioning ] ──(Daemon Inactive)──► [ Container Blocked ]
         │                                                    │
    (Containers Healthy)                                  (Remediated)
         │                                                    │
         ▼                                                    ▼
[ AI Skills Health Audit ] ◄──────────────────────────────────┘
         │
    (Skills Verified)
         │
         ▼
[ End-to-End Smoke Test ] ───(Project Test Failure)───► [ Smoke Test Failed ]
         │                                                    │
    (All Projects Passed)                                 (Retried/Fixed)
         │                                                    │
         ▼                                                    ▼
[ Ready for Development (Report Persisted) ] ◄────────────────┘
```
