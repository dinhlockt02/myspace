variable "cidr" {
  type        = string
  default     = "10.0.0.0/16"
  description = "VPC CIDR block"
}

variable "azs" {
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
  description = "Availability zones"
}

variable "project_name" {
  type        = string
  default     = "commifra"
  description = "Project name for resource naming"
}
