resource "aws_db_subnet_group" "main" {
  name       = local.resource_names.db_subnet_group
  subnet_ids = aws_subnet.public[*].id
}

resource "aws_db_instance" "main" {
  identifier     = local.resource_names.db_instance
  engine         = "postgres"
  engine_version = "16"
  instance_class = var.db_instance_class

  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username

  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  skip_final_snapshot     = var.environment != "prod"
  deletion_protection     = var.environment == "prod"
  backup_retention_period = var.environment == "prod" ? 7 : 1

  tags = { Name = local.resource_names.db_instance }
}
