variable "project_name" {
  type        = string
  description = "Project name for resource naming"
}

variable "environment" {
  type        = string
  description = "Deployment environment"
}

variable "lambda_function_name" {
  type        = string
  description = "Lambda function name"
}

variable "lambda_invoke_arn" {
  type        = string
  description = "Lambda invoke ARN"
}

variable "cors_origins" {
  type        = list(string)
  default     = ["*"]
  description = "Allowed CORS origins"
}
