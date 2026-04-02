output "app_asg_name" {
  value = module.app_infrastructure.asg_name
}

output "rds_endpoint" {
  value = module.app_infrastructure.rds_endpoint
}