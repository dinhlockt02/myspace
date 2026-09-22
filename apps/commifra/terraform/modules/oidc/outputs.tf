output "role_arn" {
  value       = aws_iam_role.oidc.arn
  description = "ARN of the OIDC role"
}

output "role_name" {
  value       = aws_iam_role.oidc.name
  description = "Name of the OIDC role"
}

output "provider_arn" {
  value       = aws_iam_openid_connect_provider.github.arn
  description = "ARN of the GitHub OIDC provider"
}
