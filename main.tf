module "app_infrastructure" {
  source        = "./modules"
  aws_region    = var.aws_region
  project_name  = var.project_name
  db_password   = var.db_password
  instance_type = var.instance_type
}