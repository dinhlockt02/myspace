output "s3_bucket_name" {
  value       = module.frontend.s3_bucket_name
  description = "Name of the S3 bucket hosting frontend static assets"
}

output "s3_bucket_arn" {
  value       = module.frontend.s3_bucket_arn
  description = "ARN of the S3 bucket hosting frontend static assets"
}

output "cloudfront_distribution_id" {
  value       = module.frontend.cloudfront_distribution_id
  description = "CloudFront distribution ID (used for cache invalidation during deployments)"
}

output "cloudfront_domain_name" {
  value       = module.frontend.cloudfront_domain_name
  description = "CloudFront domain name to access the frontend application"
}

output "api_gateway_endpoint" {
  value       = aws_apigatewayv2_api.ingestion.api_endpoint
  description = "The HTTP API Gateway endpoint for backend ingestion"
}
