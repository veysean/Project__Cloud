variable "aws_region" {
  description = "The region where we build our project"
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "The name of our cloud project"
  type        = string
  default     = "project-cloud"
}

variable "instance_type" {
  description = "The size of our server"
  type        = string
  default     = "t2.micro"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
  default     = "4/7TeamB" 
}