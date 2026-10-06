# -----------------------------------------------------------------------------
# Remote Backend Variables
# -----------------------------------------------------------------------------
variable "backend_bucket" {
  type        = string
  default     = "comminfra.myspace.dinhloc.dev"
  description = "S3 bucket for Terraform remote state"
}

variable "backend_key" {
  type        = string
  default     = "idea-collector/terraform.tfstate"
  description = "S3 key for Terraform remote state"
}

variable "backend_region" {
  type        = string
  default     = "ap-southeast-1"
  description = "AWS region for Terraform remote state bucket"
}

# -----------------------------------------------------------------------------
# General Project Variables
# -----------------------------------------------------------------------------
variable "region" {
  type        = string
  default     = "ap-southeast-1"
  description = "AWS region"
}



variable "project_name" {
  type        = string
  default     = "idea-collector"
  description = "Project name for resource naming and tagging"
}

# -----------------------------------------------------------------------------
# S3 Frontend Bucket Variables
# -----------------------------------------------------------------------------
variable "bucket_name" {
  type        = string
  default     = "idea.dinhloc.dev"
  description = "Name of the S3 bucket for hosting frontend static assets"
}

# -----------------------------------------------------------------------------
# CloudFront Distribution Variables
# -----------------------------------------------------------------------------
variable "distribution_enabled" {
  type        = bool
  default     = true
  description = "Whether the CloudFront distribution is enabled"
}

variable "is_ipv6_enabled" {
  type        = bool
  default     = true
  description = "Whether IPv6 is enabled for the CloudFront distribution"
}

variable "distribution_comment" {
  type        = string
  default     = null
  description = "Comment for the CloudFront distribution. If null, defaults to {project_name} frontend distribution."
}

variable "default_root_object" {
  type        = string
  default     = "index.html"
  description = "Default root object for CloudFront distribution"
}

variable "price_class" {
  type        = string
  default     = "PriceClass_100"
  description = "CloudFront distribution price class"
}

variable "allowed_methods" {
  type        = list(string)
  default     = ["GET", "HEAD", "OPTIONS"]
  description = "Controls which HTTP methods CloudFront processes and forwards to your origin"
}

variable "cached_methods" {
  type        = list(string)
  default     = ["GET", "HEAD"]
  description = "Controls whether CloudFront caches the response to requests using specified HTTP methods"
}

variable "viewer_protocol_policy" {
  type        = string
  default     = "redirect-to-https"
  description = "Protocol that users can use to access files (allow-all, https-only, redirect-to-https)"
}

variable "aliases" {
  type        = list(string)
  default     = []
  description = "Extra CNAMEs (alternate domain names) for the CloudFront distribution"
}

variable "acm_certificate_arn" {
  type        = string
  default     = null
  description = "ARN of the AWS Certificate Manager certificate for custom domain. Must be in us-east-1."
}

variable "cloudfront_default_certificate" {
  type        = bool
  default     = true
  description = "Whether to use default CloudFront SSL/TLS certificate"
}

variable "minimum_protocol_version" {
  type        = string
  default     = "TLSv1.2_2021"
  description = "Minimum version of the SSL protocol for custom certificate"
}

variable "geo_restriction_type" {
  type        = string
  default     = "none"
  description = "Method for geo-restriction (none, whitelist, blacklist)"
}

variable "geo_restriction_locations" {
  type        = list(string)
  default     = []
  description = "Country codes for CloudFront geo-restriction"
}

variable "custom_error_responses" {
  type = list(object({
    error_code            = number
    response_code         = number
    response_page_path    = string
    error_caching_min_ttl = optional(number, 10)
  }))
  default = [
    {
      error_code         = 403
      response_code      = 200
      response_page_path = "/index.html"
    },
    {
      error_code         = 404
      response_code      = 200
      response_page_path = "/index.html"
    }
  ]
  description = "Custom error response configurations for SPA routing"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Additional tags to apply to all resources"
}

# -----------------------------------------------------------------------------
# Custom Domain Variables
# -----------------------------------------------------------------------------
variable "domain_name" {
  type        = string
  default     = "dinhloc.dev"
  description = "The base domain name (Route53 Hosted Zone)"
}

variable "subdomain" {
  type        = string
  default     = "idea"
  description = "The subdomain to prepend to the domain name"
}
