# Base de datos de Tero: PostgreSQL en RDS, en las subnets privadas.
# La contraseña la genera RDS y la guarda en Secrets Manager
# (manage_master_user_password), así nunca pasa por el código ni por el state.

locals {
  common_tags = merge(var.tags, { Module = "database" })
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.name}-postgres"
  subnet_ids = var.subnet_ids

  tags = merge(local.common_tags, { Name = "${var.name}-postgres" })
}

# PostgreSQL 16 en RDS exige SSL por defecto, pero catalog y orders traen sslmode=disable
# en su código. Como la app se usa tal cual viene, se desactiva la exigencia de SSL.
# El tráfico no sale de la VPC: RDS está en subnets privadas y solo acepta a los servicios.
resource "aws_db_parameter_group" "this" {
  name   = "${var.name}-postgres${var.engine_version}"
  family = "postgres${var.engine_version}"

  parameter {
    name  = "rds.force_ssl"
    value = var.force_ssl ? "1" : "0"
  }

  tags = merge(local.common_tags, { Name = "${var.name}-postgres${var.engine_version}" })
}

resource "aws_db_instance" "this" {
  identifier     = "${var.name}-postgres"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_encrypted = true

  db_name                     = var.db_name
  username                    = var.username
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  parameter_group_name   = aws_db_parameter_group.this.name
  vpc_security_group_ids = [var.security_group_id]
  publicly_accessible    = false

  backup_retention_period   = var.backup_retention_days
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name}-postgres-final"
  apply_immediately         = true

  tags = merge(local.common_tags, { Name = "${var.name}-postgres" })
}
