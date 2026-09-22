variable "github_owner" {
  type        = string
  description = "GitHub repository owner"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name"
}

variable "github_token_ssm" {
  type        = string
  description = "SSM parameter path for GitHub PAT (used to generate runner registration tokens)"
  default     = "/commifra/github-runners/github-token"
}

variable "webhook_secret_ssm" {
  type        = string
  description = "SSM parameter path for webhook secret"
  default     = "/commifra/github-runners/webhook-secret"
}

variable "runner_labels" {
  type        = list(string)
  description = "Labels applied to runners"
  default     = ["self-hosted", "linux", "arm"]
}

variable "instance_types" {
  type        = list(string)
  description = "EC2 ARM64/Graviton instance types for spot runners"
  default     = ["t4g.medium"]
}

variable "runner_architecture" {
  type        = string
  description = "Instance architecture"
  default     = "arm64"
}

variable "min_count" {
  type        = number
  description = "Minimum number of runners (0 = scale to zero)"
  default     = 0
}

variable "max_count" {
  type        = number
  description = "Maximum number of concurrent runners"
  default     = 5
}

variable "vpc_id" {
  type        = string
  description = "VPC ID from commifra VPC module"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs from commifra VPC"
}

variable "block_device_size_gb" {
  type        = number
  description = "Root volume size in GB"
  default     = 50
}

variable "oidc_provider_arn" {
  type        = string
  description = "OIDC provider ARN from commifra OIDC module"
}
