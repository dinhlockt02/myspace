variable "project_name" {
  type        = string
  description = "Project name for resource naming"
}

variable "environment" {
  type        = string
  description = "Deployment environment"
}

variable "lambda_binary_path" {
  type        = string
  description = "Path to compiled Lambda binary"
}

variable "timeout" {
  type        = number
  default     = 30
  description = "Lambda timeout in seconds"
}

variable "memory_size" {
  type        = number
  default     = 128
  description = "Lambda memory size in MB"
}

variable "environment_variables" {
  type        = map(string)
  default     = {}
  description = "Environment variables for Lambda"
}
