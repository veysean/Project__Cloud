output "asg_name" {
  description = "Name of the Auto Scaling Group running the web tier."
  value       = aws_autoscaling_group.app_asg.name
}

output "rds_endpoint" {
  description = "RDS endpoint hostname:port (private)."
  value       = aws_db_instance.app_db.endpoint
}

output "alb_dns_name" {
  description = "Public DNS name of the internet-facing Application Load Balancer (ELB)."
  value       = aws_lb.app_alb.dns_name
}

output "application_url" {
  description = "Full HTTP URL to open the web app in a browser (public ELB DNS on port 80)."
  value       = "http://${aws_lb.app_alb.dns_name}"
}