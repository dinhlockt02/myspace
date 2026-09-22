variable "github_owner" {
  type        = string
  description = "GitHub repository owner"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name"
}

variable "github_pat" {
  type        = string
  sensitive   = true
  description = "GitHub PAT for runner registration (stored in SSM via Terraform)"
}

variable "github_token_ssm" {
  type        = string
  description = "SSM parameter path for GitHub PAT"
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
  default     = ["self-hosted", "linux", "x64"]
}

variable "instance_types" {
  type        = list(string)
  description = "EC2 AMD64 instance types for spot runners"
  default     = ["t3.medium"]
}

variable "runner_architecture" {
  type        = string
  description = "Instance architecture"
  default     = "x86_64"
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

variable "sqs_visibility_timeout" {
  type        = number
  default     = 300
  description = "SQS visibility timeout in seconds"
}

variable "sqs_max_retries" {
  type        = number
  default     = 3
  description = "Max retries before message goes to DLQ"
}

variable "sqs_batch_size" {
  type        = number
  default     = 1
  description = "Number of SQS messages to process per consumer invocation"
}
