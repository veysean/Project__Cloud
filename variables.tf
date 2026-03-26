variable "instance_type" {
  description = "EC2 instance type"
  default     = "t2.micro"
}
variable "aws_region" {
  description = "AWS region to deploy resources"
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Name prefix for resources"
  default     = "project-cloud"
}
