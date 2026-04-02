output "asg_name" {
  value = aws_autoscaling_group.app_asg.name
}

output "rds_endpoint" {
  value = aws_db_instance.app_db.endpoint
}

output "alb_dns_name" {
  value = aws_lb.app_alb.dns_name
}