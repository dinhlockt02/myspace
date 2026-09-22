variable "github_org" {
  type        = string
  description = "GitHub organization or username"
}

variable "github_repo" {
  type        = string
  description = "Repository name"
}

variable "allowed_environments" {
  type        = list(string)
  default     = ["prod", "dev"]
  description = "GitHub environments allowed to assume this role"
}
