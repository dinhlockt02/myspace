# AGENTS.md

## Monorepo structure

- Multi-language monorepo; each project lives under its own top-level directory
- Infrastructure as code: `infra/` (Terraform, AWS, Kubernetes manifests)
- Shared libraries, configs, and tooling: `packages/` or `shared/`
- CI/CD: GitHub Actions in `.github/workflows/`

## AI-native SDLC (autonomous pipeline)

- Agents write code, open PRs, review, and manage deploys end-to-end
- Humans set direction and approve only when required by policy
- Every PR must include a clear description of intent, scope, and verification steps
- Agents must run lint, typecheck, and tests before opening a PR
- No speculative changes — only implement what the task explicitly requires

## Infra conventions

- Terraform for all AWS resources; no manual console changes
- Kubernetes manifests or Helm charts in `infra/k8s/` or per-service `deploy/`
- State managed remotely (S3 + DynamoDB lock or equivalent)
- Changes to `infra/` require explicit approval before merge

## CI/CD conventions

- GitHub Actions for all pipelines
- Each service/package has its own workflow or matrix entry
- Required checks: lint, typecheck, test, build
- Deploy is triggered by merge to main or tag push

## Agent constraints

- Do not commit secrets or credentials
- Do not modify CI/CD workflows without explicit instruction
- Do not change infra state without explicit instruction
- Follow existing code style in each project; do not reformat unrelated code
- When adding a new service or package, add corresponding CI workflow
