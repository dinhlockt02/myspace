output "webhook_url" {
  value       = aws_lambda_function_url.webhook.function_url
  description = "URL to configure in GitHub repo webhook settings"
}

output "webhook_secret_ssm_path" {
  value       = var.webhook_secret_ssm
  description = "SSM path where the webhook secret is stored"
}

output "runner_role_arn" {
  value       = aws_iam_role.runner.arn
  description = "IAM role ARN attached to runner instances"
}

output "runner_security_group_id" {
  value       = aws_security_group.runner.id
  description = "Security group ID for runner instances"
}
