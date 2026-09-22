variable "bucket_name" {
  type        = string
  description = "Bucket for store all common infra"
  default     = "comminfra.myspace.dinhloc.dev"
}

variable "region" {
  type        = string
  default     = "ap-southeast-1"
  description = "AWS region"
}
