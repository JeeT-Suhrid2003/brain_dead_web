output "instance_id" {
  description = "EC2 instance ID; connect with Systems Manager Session Manager."
  value       = aws_instance.app.id
}

output "api_url" {
  description = "Records API base URL; reachable only when allowed_app_cidr permits your client."
  value       = "http://${aws_instance.app.public_ip}:5000"
}

output "health_url" {
  description = "Database-backed health check URL."
  value       = "http://${aws_instance.app.public_ip}:5000/health"
}

output "database_endpoint" {
  description = "Private RDS endpoint; not reachable directly from the internet."
  value       = aws_db_instance.main.address
}
