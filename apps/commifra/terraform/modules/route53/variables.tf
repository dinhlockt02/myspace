variable "domain_name" {
  description = "The domain name to register and create a hosted zone for"
  type        = string
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

