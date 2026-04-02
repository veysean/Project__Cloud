# modules/variables.tf

variable "aws_region" {
  type = string
}

variable "project_name" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "db_password" {
  type      = string
  sensitive = true
}