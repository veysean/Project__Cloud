output "web_instance_public_ip" {
  value = module.app_infrastructure.instance_public_ip 
}

output "rds_endpoint" {
  value = module.app_infrastructure.rds_endpoint
}