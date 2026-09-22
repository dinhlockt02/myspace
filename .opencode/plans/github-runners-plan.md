# Plan: GitHub Self-Hosted Runners on AWS

## Overview

Add ephemeral, self-hosted GitHub Actions runners to `apps/commifra` as a new Terraform module. Runners are provisioned on-demand as EC2 spot instances via Lambda, triggered by GitHub webhook events. Scope is repo-level only. Runner architecture is ARM64.

**Approach**: Lambda + EC2 spot instances (ephemeral per-job, scale to zero). Runner instances authenticate to AWS via OIDC — no long-lived credentials on the instance.

---

## File Structure

```
apps/commifra/terraform/modules/
└── github-runners/
    ├── main.tf                # module composition, Lambda, ASG, launch template
    ├── variables.tf           # labels, instance types, webhook config
    ├── outputs.tf             # webhook URL, runner role ARN
    ├── runner-config.tf       # runner startup script, ARM64 tooling
    ├── iam.tf                 # runner instance profile, OIDC trust policy
    └── webhook.tf             # Lambda + Function URL for GitHub webhook
```

Lives inside `apps/commifra/terraform/modules/github-runners/` and is composed from `apps/commifra/terraform/main.tf`.

---

## Module Details

### `github-runners`

**Purpose**: Ephemeral self-hosted ARM64 runners, repo-scoped, scale to zero.

**Resources**:
- Lambda function (webhook receiver + instance dispatcher)
- EC2 launch template (ARM64 spot instances, Graviton)
- Auto Scaling group (min=0, scales on webhook events)
- IAM role for runner instances — OIDC trust policy scoped to this repo
- IAM role for Lambda (EC2, ASG, SSM, CloudWatch)
- Lambda Function URL (webhook endpoint, no API Gateway cost)
- CloudWatch log groups (Lambda + runner instances, KMS-encrypted)
- Security group (runner instances in commifra VPC private subnets)
- SSM parameters (webhook secret)

**Runner instance config** (startup script installs on ARM64 Ubuntu):
- `actions/runner` binary (ARM64 build)
- Docker
- Node.js 20 (ARM64), pnpm
- Terraform (ARM64)
- AWS CLI v2
- Common build tools (git, jq, curl)

**Variables**:
| Variable | Type | Default | Description |
|---|---|---|---|
| `github_owner` | string | — | GitHub repo owner (user or org) |
| `github_repo` | string | — | Repository name |
| `webhook_secret_ssm` | string | `"/commifra/github-runners/webhook-secret"` | SSM path for webhook secret |
| `runner_labels` | list(string) | `["self-hosted", "linux", "arm"]` | Labels applied to runners |
| `instance_types` | list(string) | `["t4g.medium"]` | ARM64/Graviton instance type pool |
| `runner_architecture` | string | `"arm64"` | Instance architecture |
| `min_count` | number | `0` | Min runners (0 = scale to zero) |
| `max_count` | number | `5` | Max concurrent runners |
| `vpc_id` | string | — | From commifra VPC module |
| `subnet_ids` | list(string) | — | Private subnet IDs from commifra VPC |
| `kms_key_arn` | string | — | From commifra KMS module (encrypt logs) |
| `block_device_size_gb` | number | `50` | Root volume size |

**Outputs**:
- `webhook_url` — URL to configure in GitHub repo webhook settings
- `webhook_secret_ssm_path` — SSM path where webhook secret is stored
- `runner_role_arn` — IAM role ARN attached to runner instances (OIDC trust)
- `runner_security_group_id`

---

## Authentication: OIDC

Runner instances assume an IAM role via **GitHub Actions OIDC** — no long-lived AWS credentials on the instance.

### Runner IAM Role (OIDC trust policy)

The runner instance profile uses an OIDC trust policy scoped to this specific repo:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::<account>:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:<owner>/<repo>:*"
        }
      }
    }
  ]
}
```

This reuses the OIDC provider already created by commifra's `oidc` module. The runner role is a **separate role** from the deploy role — minimal permissions for the runner environment only.

### Runner IAM Permissions

Minimal permissions for the runner environment:
- `ssm:GetParameter` — read deploy secrets at runtime
- `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents` — CloudWatch logging
- `s3:GetObject` — read build artifacts from state bucket if needed
- `ecr:GetAuthorizationToken`, `ecr:BatchGetImage`, `ecr:GetDownloadUrlForLayer` — pull container images
- `sts:AssumeRole` — assume the commifra deploy OIDC role for actual deployments

No admin permissions on the runner role. Deploy permissions come through assuming the deploy OIDC role within workflow steps.

### Webhook Secret

A random webhook secret is generated and stored in SSM (encrypted with commifra KMS):

```bash
# After apply, retrieve the generated secret:
aws ssm get-parameter \
  --name "/commifra/github-runners/webhook-secret" \
  --with-decryption \
  --query "Parameter.Value" --output text
```

This secret is configured in the GitHub repo webhook settings. No GitHub App or PAT required.

---

## Integration with `commifra/terraform/main.tf`

Add to `apps/commifra/terraform/main.tf`:

```hcl
module "github_runners" {
  source = "./modules/github-runners"

  github_owner       = var.github_owner
  github_repo        = var.github_repo
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.private_subnet_ids
  kms_key_arn        = module.kms.key_arn
  runner_labels      = ["self-hosted", "linux", "arm"]
  instance_types     = var.runner_instance_types
  runner_architecture = "arm64"
  max_count          = 5
}
```

Add to `apps/commifra/terraform/variables.tf`:
```hcl
variable "github_owner" {
  type        = string
  description = "GitHub repository owner"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name"
}

variable "runner_instance_types" {
  type        = list(string)
  description = "EC2 ARM64/Graviton instance types for spot runners"
  default     = ["t4g.medium"]
}
```

Add to `apps/commifra/terraform/terraform.tfvars.example`:
```hcl
github_owner         = "loctran"
github_repo          = "myspace"
runner_instance_types = ["t4g.medium"]
```

---

## GitHub Webhook Configuration

After `terraform apply`, configure the webhook in GitHub:

1. Go to repo **Settings → Webhooks → Add webhook**
2. **Payload URL**: value of `module.github_runners.webhook_url`
3. **Content type**: `application/json`
4. **Secret**: retrieve from SSM at `/commifra/github-runners/webhook-secret`
5. **Events**: select **Workflow jobs** only
6. **Active**: ✅

---

## Using Runners in Workflows

Update workflows to target self-hosted ARM runners:

```yaml
jobs:
  build:
    runs-on: [self-hosted, linux, arm]
```

The runner instance startup script installs ARM64 builds of all tooling (Node.js, Terraform, Docker, AWS CLI).

### OIDC in workflows

Runners use OIDC for AWS access — no secrets needed in the workflow:

```yaml
jobs:
  deploy:
    runs-on: [self-hosted, linux, arm]
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ vars.AWS_ROLE_ARN }}
          aws-region: us-east-1
```

---

## Nx Targets

No new Nx targets needed — runners are part of `commifra` and deploy with:
```bash
pnpm nx run commifra:plan
pnpm nx run commifra:apply
```

---

## GitHub Actions Workflow Update

Add runner-related outputs to `.github/workflows/commifra.yml` plan step so PR reviewers see runner config changes.

No separate workflow needed.

---

## Cost Estimate

| Resource | Cost |
|---|---|
| Lambda (webhook + dispatcher) | ~$0 (invocation-based, low volume) |
| EC2 spot (t4g.medium, ARM64) | ~$0.02/hr per runner |
| Lambda Function URL | Free |
| CloudWatch Logs | ~$0.50/GB |
| SSM parameters | Free (standard tier) |

Idle cost: **$0/month** (min_count=0, scale to zero).
Spot ARM64 instances are ~60% cheaper than equivalent x86 on-demand.

---

## Execution Steps

1. **Create `github-runners` module** — all Terraform files
2. **Wire into `commifra/terraform/main.tf`** — add module block + variables
3. **Apply** — `pnpm nx run commifra:plan` then `pnpm nx run commifra:apply`
4. **Configure webhook** — retrieve secret from SSM, add webhook in GitHub repo settings
5. **Update workflows** — change `runs-on` to `[self-hosted, linux, arm]`
6. **Verify** — trigger a workflow run, confirm it picks up the self-hosted runner

---

## Security Considerations

- Runners run in **private subnets** (no public IP), NAT gateway for outbound
- Ephemeral: each job runs on a fresh instance, destroyed after job completes
- OIDC: runner instances assume IAM roles via GitHub's OIDC provider — no long-lived credentials
- Spot instances: interrupted jobs are re-queued by GitHub automatically
- Runner startup script is version-controlled in `runner-config.tf`
- All logs encrypted with commifra KMS key
- Webhook secret stored in SSM, encrypted with commifra KMS

---

## Out of Scope

- Org-level runners (repo-scoped only)
- x86 runners (ARM64 only; can add a second module instance for x86 later)
- Custom AMI baking (uses default Ubuntu 22.04 ARM64 AMI; custom AMI can be added later)
- Windows runners
- Instance type tuning (defaults to `t4g.medium`; adjust `runner_instance_types` variable as needed)

---

## Summary

- **Location**: `apps/commifra/terraform/modules/github-runners/`
- **Scope**: Repo-level only
- **Approach**: Lambda + EC2 spot, ephemeral per-job, scale to zero
- **Architecture**: ARM64 (Graviton)
- **Auth**: OIDC — runner instances assume IAM roles via GitHub's OIDC provider, no long-lived credentials
- **Network**: Private subnets in commifra VPC
- **Cost**: $0 idle, ~$0.02/hr per active ARM64 runner
- **Deploy**: Via existing `commifra:apply` workflow
