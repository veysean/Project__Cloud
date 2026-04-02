output "app_asg_name" {
  value = module.app_infrastructure.asg_name
}

output "rds_endpoint" {
  value = module.app_infrastructure.rds_endpoint
}

output "application_url" {
  value = "http://${module.app_infrastructure.alb_dns_name}"
}