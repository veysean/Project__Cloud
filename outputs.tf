output "app_asg_name" {
  description = "Auto Scaling Group for EC2 instances behind the load balancer."
  value       = module.app_infrastructure.asg_name
}

output "rds_endpoint" {
  description = "PostgreSQL endpoint (private)."
  value       = module.app_infrastructure.rds_endpoint
}

output "alb_public_dns_name" {
  description = "Public DNS hostname of the Application Load Balancer (requirement: app reachable via ELB DNS)."
  value       = module.app_infrastructure.alb_dns_name
}

output "application_url" {
  description = "Primary entry point: functional web app over HTTP via the ELB public DNS name."
  value       = module.app_infrastructure.application_url
}