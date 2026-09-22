# Plan: Create `apps/commifra` — Common Infrastructure App

## Overview

Create a new app called `commifra` (common infrastructure) that manages shared AWS resources used across all apps in the monorepo. This includes Terraform state backend, GitHub OIDC for CI/CD, shared VPC, KMS encryption, secrets management, DNS, and centralized logging.

---

## File Structure

```
apps/commifra/
├── project.json                          # Nx project config
├── package.json                          # Workspace stub
├── .gitignore                            # Terraform state files
├── README.md                             # Bootstrap + usage instructions
│
├── bootstrap/                            # Phase 1: local backend, creates S3 bucket
│   ├── main.tf                           #   provider + state-backend module only
│   ├── variables.tf                      #   bucket_name, region
│   └── outputs.tf                        #   bucket_name, bucket_region
│
└── terraform/                            # Phase 2: S3 backend (native locking)
    ├── main.tf                           #   composes all modules
    ├── backend.tf                        #   backend "s3" { use_lockfile = true }
    ├── variables.tf                      #   region, bucket_name, domain_name, vpc_cidr, etc.
    ├── terraform.tfvars.example          #   sample values
    ├── outputs.tf                        #   role ARN, bucket, VPC id, zone id
    └── modules/
        ├── state-backend/                # S3 bucket with native locking
        ├── oidc/                         # GitHub OIDC provider + IAM role
        ├── vpc/                          # Shared VPC (10.0.0.0/16, 3 AZs)
        ├── kms/                          # Shared KMS key + alias
        ├── secrets-manager/              # Shared secrets store
        ├── route53/                      # Hosted zone (placeholder domain)
        └── cloudwatch/                   # Centralized log groups
```

---

## Module Details

### 1. `state-backend`
**Purpose**: S3 bucket for Terraform state with native locking (Terraform 1.9+)

**Resources**:
- `aws_s3_bucket` — versioned, server-side encrypted
- `aws_s3_bucket_versioning` — enabled
- `aws_s3_bucket_server_side_encryption_configuration` — AES256
- `aws_s3_bucket_lifecycle_configuration` — expire old versions after 90 days
- `aws_s3_bucket_policy` — deny non-SSL requests
- `aws_s3_bucket_public_access_block` — block all public access

**Variables**:
- `bucket_name` (string) — globally unique bucket name
- `region` (string) — AWS region

**Outputs**:
- `bucket_name`
- `bucket_arn`
- `bucket_region`

---

### 2. `oidc`
**Purpose**: GitHub OIDC provider + IAM role for CI/CD (no long-lived secrets)

**Resources**:
- `aws_iam_openid_connect_provider` — GitHub OIDC provider
- `aws_iam_role` — role with OIDC trust policy scoped to repo + environments
- `aws_iam_role_policy` — permissions (AdministratorAccess or custom policy)

**Trust policy**:
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
          "token.actions.githubusercontent.com:sub": "repo:<github_org>/<github_repo>:*"
        }
      }
    }
  ]
}
```

**Variables**:
- `github_org` (string) — GitHub organization or username
- `github_repo` (string) — repository name
- `allowed_environments` (list) — GitHub environments (e.g., `["prod", "dev"]`)

**Outputs**:
- `role_arn` — ARN of the OIDC role (used in GitHub Actions)
- `role_name`

---

### 3. `vpc`
**Purpose**: Shared VPC with public and private subnets across 3 AZs

**Resources**:
- `aws_vpc` — 10.0.0.0/16
- `aws_subnet` — 3 public (10.0.1.0/24, 10.0.2.0/24, 10.0.3.0/24) + 3 private (10.0.101.0/24, 10.0.102.0/24, 10.0.103.0/24)
- `aws_internet_gateway`
- `aws_eip` — NAT gateway IP
- `aws_nat_gateway` — in first public subnet
- `aws_route_table` — public + private route tables
- `aws_route` — default route to IGW/NAT

**Variables**:
- `cidr` (string, default `10.0.0.0/16`)
- `azs` (list, default `["us-east-1a", "us-east-1b", "us-east-1c"]`)
- `project_name` (string)

**Outputs**:
- `vpc_id`
- `public_subnet_ids` (list)
- `private_subnet_ids` (list)
- `vpc_cidr`

---

### 4. `kms`
**Purpose**: Shared KMS key for encrypting secrets

**Resources**:
- `aws_kms_key` — symmetric encryption key
- `aws_kms_alias` — alias for easier reference

**Variables**:
- `key_alias` (string, default `alias/commifra-shared`)
- `deletion_window` (number, default 30)

**Outputs**:
- `key_arn`
- `key_id`
- `alias_arn`

---

### 5. `secrets-manager`
**Purpose**: Centralized secrets storage (encrypted with KMS)

**Resources**:
- `aws_secretsmanager_secret` — one per secret name
- `aws_secretsmanager_secret_version` — initial placeholder value

**Variables**:
- `secret_names` (list) — names of secrets to create (e.g., `["DB_URL", "API_KEY"]`)
- `kms_key_arn` (string) — KMS key for encryption

**Outputs**:
- `secret_arns` (map) — name → ARN

---

### 6. `route53`
**Purpose**: Shared DNS hosted zone

**Resources**:
- `aws_route53_zone` — hosted zone for domain

**Variables**:
- `domain_name` (string, default `example.com`) — placeholder, user fills in later

**Outputs**:
- `zone_id`
- `zone_name_servers` (list)

---

### 7. `cloudwatch`
**Purpose**: Centralized log groups with KMS encryption

**Resources**:
- `aws_cloudwatch_log_group` — one per service

**Variables**:
- `log_groups` (map) — name → retention_in_days (e.g., `{"idea-collector-backend": 30}`)
- `kms_key_arn` (string)

**Outputs**:
- `log_group_arns` (map)

---

## Workspace Integration

### `pnpm-workspace.yaml` update
```yaml
packages:
  - 'apps/*/frontend'
  - 'apps/*/backend'
  - 'apps/commifra'
```

### `project.json` (Nx targets)
```json
{
  "name": "commifra",
  "targets": {
    "validate": {
      "command": "cd apps/commifra/terraform && terraform validate"
    },
    "fmt": {
      "command": "cd apps/commifra/terraform && terraform fmt -check -recursive"
    },
    "plan-bootstrap": {
      "command": "cd apps/commifra/bootstrap && terraform init -backend=false && terraform plan"
    },
    "apply-bootstrap": {
      "command": "cd apps/commifra/bootstrap && terraform apply"
    },
    "plan": {
      "command": "cd apps/commifra/terraform && terraform init && terraform plan"
    },
    "apply": {
      "command": "cd apps/commifra/terraform && terraform apply -auto-approve"
    }
  }
}
```

---

## GitHub Actions Changes

### New workflow: `.github/workflows/commifra.yml`

**Triggers**:
- PRs touching `apps/commifra/**`
- Push to `main`

**Jobs**:
1. **check** (on PR):
   - `terraform fmt -check`
   - `terraform validate`
   - `terraform plan` (read-only)

2. **deploy** (on merge to main):
   - `terraform apply` gated behind GitHub environment `commifra-prod` (manual approval)
   - Uses OIDC role ARN (after bootstrap)

**First deploy**: Manual local apply (documented in README)

---

## idea-collector/deploy Migration (Post-Bootstrap)

### Step 1: Update backend config
Replace `backend "local" {}` in `apps/idea-collector/deploy/envs/{dev,prod}/main.tf`:
```hcl
backend "s3" {
  bucket         = "<commifra-bucket-name>"
  key            = "idea-collector/<env>/terraform.tfstate"
  region         = "us-east-1"
  use_lockfile   = true
}
```

### Step 2: Migrate state
```bash
cd apps/idea-collector/deploy/envs/dev
terraform init -migrate-state

cd ../prod
terraform init -migrate-state
```

### Step 3: Update deploy workflow
Existing `deploy.yml` already runs `terraform init` — no changes needed (will work with remote state).

---

## Bootstrap Procedure (Manual First Apply)

### Phase 1: Create S3 bucket locally
```bash
# Set AWS credentials in environment
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...

# Run bootstrap
pnpm nx run commifra:apply-bootstrap

# Note the bucket name from output
```

### Phase 2: Switch to S3 backend
1. Edit `apps/commifra/terraform/backend.tf` — uncomment S3 backend block
2. Fill in bucket name from Phase 1 output
3. Run:
   ```bash
   cd apps/commifra/terraform
   terraform init -migrate-state
   ```

### Phase 3: Apply full infra
```bash
pnpm nx run commifra:apply
```
This imports the S3 bucket into state and provisions all other modules (OIDC, VPC, KMS, Route53, CloudWatch).

### Phase 4: Configure GitHub
1. Add OIDC role ARN to GitHub environment secrets:
   - `commifra-prod` environment → `AWS_ROLE_ARN`
   - `dev` and `prod` environments (for idea-collector) → `AWS_ROLE_ARN`
2. All future deploys use OIDC (no long-lived secrets)

---

## Variables (terraform.tfvars.example)

```hcl
region          = "us-east-1"
bucket_name     = "myspace-terraform-state-<account-id>"
github_org      = "loctran"
github_repo     = "myspace"
allowed_environments = ["prod", "dev"]
domain_name     = "example.com"  # Replace with actual domain
vpc_cidr        = "10.0.0.0/16"
azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
secret_names    = ["DB_URL", "API_KEY"]
log_groups = {
  "idea-collector-backend" = 30
}
```

---

## Execution Steps

1. **Create file structure** — all Terraform modules and configs
2. **Update workspace** — add commifra to `pnpm-workspace.yaml`
3. **Add Nx project** — `project.json` with targets
4. **Create GitHub workflow** — `commifra.yml` for CI/CD
5. **Write README** — bootstrap instructions
6. **Update idea-collector/deploy** — migrate to S3 backend (post-bootstrap)

---

## Summary

- **Scope**: S3 state backend (native locking), GitHub OIDC, shared VPC (10.0.0.0/16, 3 AZs), KMS, Secrets Manager, Route53 (placeholder), CloudWatch
- **Bootstrap**: Local backend first, then migrate to S3
- **State**: Single prod stack (no dev/prod split for commifra)
- **Migration**: idea-collector will use commifra's S3 backend
- **DNS**: Placeholder variable (user fills in later)
- **Auth**: Manual local apply for bootstrap, OIDC for all future deploys
