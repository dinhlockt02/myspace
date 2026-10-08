variable "region" {
  type        = string
  default     = "ap-southeast-1"
  description = "AWS region"
}

variable "github_owner" {
  type        = string
  description = "GitHub repository owner"
  default = "dinhlockt02@20945393"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name"
  default = "myspace@1373158525"
}

variable "github_pat" {
  type        = string
  sensitive   = true
  description = "GitHub PAT for runner registration (stored in SSM)"
}

variable "vpc_cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "VPC CIDR block"
}

variable "vpc_azs" {
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
  description = "VPC availability zones"
}

variable "allowed_environments" {
  type        = list(string)
  default     = ["prod", "dev"]
  description = "GitHub environments allowed to assume the OIDC role"
}

variable "runner_instance_types" {
  type        = list(string)
  description = "EC2 AMD64 instance types for spot runners"
  default     = ["t3.medium"]
}

variable "runner_max_count" {
  type        = number
  description = "Maximum number of concurrent runners"
  default     = 5
}

variable "domain_name" {
  type        = string
  description = "The root domain name"
  default     = "dinhloc.dev"
}

