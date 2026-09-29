output "route53_zone_id" {
  description = "The Hosted Zone ID"
  value       = aws_route53_zone.this.zone_id
}

output "route53_zone_name_servers" {
  description = "Name servers of the created hosted zone"
  value       = aws_route53_zone.this.name_servers
}

