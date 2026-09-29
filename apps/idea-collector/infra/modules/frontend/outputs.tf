output "s3_bucket_name" {
  value       = aws_s3_bucket.frontend.id
  description = "Name of the S3 bucket hosting frontend static assets"
}

output "s3_bucket_arn" {
  value       = aws_s3_bucket.frontend.arn
  description = "ARN of the S3 bucket hosting frontend static assets"
}

output "cloudfront_distribution_id" {
  value       = aws_cloudfront_distribution.frontend.id
  description = "CloudFront distribution ID (used for cache invalidation during deployments)"
}

output "cloudfront_domain_name" {
  value       = aws_cloudfront_distribution.frontend.domain_name
  description = "CloudFront domain name to access the frontend application"
}
