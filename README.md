# myspace

A multi-language monorepo of personal projects, built and operated through an AI-native software
development lifecycle: agents write code, open PRs, review and manage deploys, while humans set
direction and approve where policy requires.

## Projects

| Project | Description | Stack |
| :--- | :--- | :--- |
| [`apps/idea-collector`](apps/idea-collector/README.md) | Serverless app to capture and organize ideas in private, per-user workspaces (Google sign-in via Cognito) | React 19 + Vite, Go on AWS Lambda, DynamoDB, Terraform |
| [`apps/commifra`](apps/commifra) | Shared AWS infrastructure: OIDC, VPC, Route 53 and self-hosted GitHub runners | Terraform, Lambda |

## Repository layout

```text
.
├── apps/          # One directory per project (frontend, backend, infra live inside each)
├── docs/          # Onboarding guide and AI-related documentation
├── scripts/       # Developer tooling: setup-dev.sh, pr-workflow.sh
├── specs/         # Spec Kit feature specs, plans and tasks (NNN-feature-name)
├── .github/       # GitHub Actions workflows and composite actions
├── .claude/       # Claude Code settings, hooks and skills
├── .specify/      # Spec Kit config, templates and the project constitution
├── AGENTS.md      # Rules for AI agents working in this repo
├── nx.json        # Nx task runner configuration
└── pnpm-workspace.yaml
```

## Getting started

Prerequisites: Node.js >= 20, pnpm >= 9, Go >= 1.22, Docker with Compose >= 2.20, and the GitHub CLI
(`gh`). Full details are in [docs/ONBOARDING.md](docs/ONBOARDING.md).

```bash
pnpm run setup          # detect prerequisites, install dependencies, start containers, run smoke tests
pnpm run setup -- --help  # see all options
```

Common tasks run through [Nx](https://nx.dev):

```bash
pnpm lint               # lint every project
pnpm test               # test every project
pnpm build              # build every project
pnpm nx run <project>:<target>   # run one target, e.g. idea-collector-infra:plan
```

## Workflow

Work follows [Spec Kit](https://github.com/github/spec-kit). Use the slash commands in Claude Code:

1. `/speckit-specify` then `/speckit-clarify`: write and refine the feature spec
2. `/speckit-plan`, `/speckit-tasks`, `/speckit-analyze`: plan and break down the work
3. `/speckit-implement`: build the tasks
4. `/speckit-pr`: create, update and monitor the pull request (`pnpm run pr` runs the same CLI)
5. `/speckit-commit`: write a validated Conventional Commits message for the staged changes and commit it (`pnpm run commit` runs the same CLI)

The principles that govern all of this live in the
[constitution](.specify/memory/constitution.md).

### Branches

Never commit to `main`. Branch names follow `<type>/<description>` or `<type>/<scope>/<description>`
(types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`, `ci`, `infra`, `req`; scope optional),
or `NNN-<description>` for Spec Kit features. Descriptions are lowercase kebab-case, 3-50
characters. A Claude Code hook enforces this; see [AGENTS.md](AGENTS.md).

## CI/CD

GitHub Actions in [`.github/workflows`](.github/workflows) run lint, typecheck, test and build per
project, plus `terraform plan` on pull requests. Merging to `main` triggers deployment, including
`terraform apply`. Changes under `infra/` and to workflows require explicit approval before merge.

## Conventions

- Infrastructure is Terraform for all AWS resources, with remote state. No manual console changes.
- Never commit secrets or credentials. CI receives them from GitHub repository secrets.
- Follow each project's existing code style, and keep changes limited to the task at hand.
