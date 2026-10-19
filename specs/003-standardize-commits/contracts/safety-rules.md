# Safety Rules: Sensitive Paths and Credential Patterns

**Feature**: `003-standardize-commits` | Single source of truth for `scripts/lib/commit-safety.sh` and `scripts/lib/secret-patterns.sh` (FR-009, SC-004).

## Scope of the guarantee

SC-004 is a guarantee about **the patterns listed here**, not about every possible secret. The workflow blocks:

1. staged **file paths** that conventionally hold secrets (section 1), and
2. staged **content** that matches a high-confidence credential **format** (section 2).

It does not detect free-form secrets such as `password = hunter2` or an arbitrary high-entropy string. Those cannot be matched without false positives that nobody could clear (content findings are not overridable), so they are out of scope and must be caught in review. The pattern list can grow; each addition needs a test in `scripts/tests/cases/us2-commit.sh` and a check that it matches no tracked file in the repository.

## 1. Sensitive paths (blocking, overridable per path with `--allow-sensitive <path>`)

| Pattern | Notes |
| :--- | :--- |
| `.env`, `.env.*` | Not `*.example`, `*.sample`, `*.template` |
| `*.pem`, `*.key`, `*.p12`, `id_rsa*` | Private key material (not `*.pub`, which are public keys) |
| `*.tfstate`, `*.tfstate.*` | Terraform state |
| `*.tfvars` | Not `*.tfvars.example` |
| `credentials` | File named exactly `credentials` |

The repository deliberately tracks `apps/idea-collector/frontend/.env` (public Cognito IDs). Changing it needs `--allow-sensitive apps/idea-collector/frontend/.env`.

## 2. Credential content patterns (blocking, never overridable)

Matched with `grep -E` against `git diff --cached` added lines. The matched text is never printed; only the path and the rule name are.

| Rule name | Pattern (ERE) | Source | Set |
| :--- | :--- | :--- | :--- |
| `aws-secret-access-key` | `aws_secret_access_key[[:space:]]*=[[:space:]]*[A-Za-z0-9/+=]{30,}` | existing PR gate | base |
| `github-token-ghp` | `ghp_[a-zA-Z0-9]{36}` | existing PR gate | base |
| `private-key-block` | `BEGIN[[:space:]]+(RSA\|EC\|OPENSSH\|DSA)[[:space:]]+PRIVATE[[:space:]]+KEY` | existing PR gate | base |
| `aws-access-key-id` | `AKIA[0-9A-Z]{16}` | AWS key ID format | extended |
| `google-oauth-client-secret` | `GOCSPX-[A-Za-z0-9_-]{20,}` | Google OAuth client secrets (this repo uses Google sign-in) | extended |
| `slack-token` | `xox[baprs]-[A-Za-z0-9-]{10,}` | Slack token format | extended |
| `github-token` | `gh[opusr]_[A-Za-z0-9]{36}` | GitHub token family | extended |
| `github-fine-grained-pat` | `github_pat_[A-Za-z0-9_]{22,}` | GitHub fine-grained PAT | extended |
| `pgp-private-key` | `BEGIN[ ]PGP[ ]PRIVATE[ ]KEY[ ]BLOCK` (bracket form so the pattern does not match its own text) | PGP private key | extended |

`secret-patterns.sh` exposes two variables:

- `SECRET_PATTERN`: the **base** set, exactly what `scripts/lib/pr-gates.sh` uses today. `pr-gates.sh` keeps using only this, so PR gate behaviour does not change.
- `SECRET_PATTERN_EXTENDED`: base plus extended, used by `commit-safety.sh`.

**Self-reference rule**: no pattern may match the text of its own definition, or the workflow would refuse to commit `secret-patterns.sh` and this document. Write literal spaces inside a pattern as `[ ]`, and build fake secrets in tests and docs at runtime instead of writing them out.

## 3. Verified properties (at spec time)

- Every extended pattern matched a synthetic sample of its format.
- None of the patterns matched any tracked file in the repository, and none matched the lines `client_secret = var.google_client_secret`, `TF_VAR_google_client_secret: ${{ secrets.TF_VAR_GOOGLE_CLIENT_SECRET }}` or `VITE_COGNITO_CLIENT_ID=<id>`.
