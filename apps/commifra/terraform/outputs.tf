output "webhook_url" {
  value       = module.github_runners.webhook_url
  description = "URL to configure in GitHub repo webhook settings"
}

output "webhook_secret_ssm_path" {
  value       = module.github_runners.webhook_secret_ssm_path
  description = "SSM path where the webhook secret is stored"
}

output "runner_role_arn" {
  value       = module.github_runners.runner_role_arn
  description = "IAM role ARN attached to runner instances"
}

output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "VPC ID"
}

output "private_subnet_ids" {
  value       = module.vpc.private_subnet_ids
  description = "Private subnet IDs"
}

output "public_subnet_ids" {
  value       = module.vpc.public_subnet_ids
  description = "Public subnet IDs"
}

output "oidc_role_arn" {
  value       = module.oidc.role_arn
  description = "OIDC role ARN for GitHub Actions"
}

output "oidc_provider_arn" {
  value       = module.oidc.provider_arn
  description = "OIDC provider ARN"
}
