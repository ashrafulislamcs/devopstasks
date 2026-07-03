output "db_endpoint" {
  value     = aws_db_instance.this.endpoint
  sensitive = true
}

output "db_secret_arn" {
  value = aws_secretsmanager_secret.db.arn
}

output "private_dns_name" {
  value = aws_route53_record.db.fqdn
}
