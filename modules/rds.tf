# Groups private subnets across multiple AZs for database high-availability
resource "aws_db_subnet_group" "main" {
  name = "${var.project_name}-db-subnet-group"
  subnet_ids = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id
  ]

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

# Provisions the RDS PostgreSQL instance with isolated security and secure credentials
resource "aws_db_instance" "app_db" {
  allocated_storage      = 20
  engine                 = "postgres"
  engine_version         = "11"
  instance_class         = "db.t3.micro"
  db_name                = "projectdb"
  username               = "dbadmin"
  password               = var.db_password
  skip_final_snapshot    = true
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  # Necessary for PostgreSQL
  publicly_accessible = false

  tags = {
    Name = "${var.project_name}-db"
  }
}