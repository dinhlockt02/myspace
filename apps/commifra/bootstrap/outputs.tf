output "bucket_name" {
  value       = var.bucket_name
  description = "Name of the S3 bucket for Terraform state"
}

output "bucket_region" {
  value       = var.region
  description = "Region of the S3 bucket"
}
