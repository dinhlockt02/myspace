variable "project_name" {
  type        = string
  default     = "idea-collector"
  description = "Project name"
}

variable "lambda_binary_path" {
  type        = string
  default     = "../../../backend/main"
  description = "Path to compiled Lambda binary"
}

variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region"
}
