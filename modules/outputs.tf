output "asg_name" {
  value = aws_autoscaling_group.app_asg.name
}

output "rds_endpoint" {
  value = aws_db_instance.app_db.endpoint
}
