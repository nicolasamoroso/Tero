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

# RDS crea este log group solo si no existe, y sin retención. Se crea antes desde Terraform
# para que respete la retención del ambiente y se borre con el destroy.
resource "aws_cloudwatch_log_group" "postgresql" {
  #checkov:skip=CKV_AWS_158:CloudWatch ya encripta los logs con claves administradas por AWS; una clave KMS propia suma costo
  #checkov:skip=CKV_AWS_338:La retención se define por ambiente (log_retention_days); un año de logs en Academy es costo sin uso
  name              = "/aws/rds/instance/${var.name}-postgres/postgresql"
  retention_in_days = var.log_retention_days

  tags = merge(local.common_tags, { Name = "${var.name}-postgres-logs" })
}

resource "aws_db_instance" "this" {
  #checkov:skip=CKV_AWS_293:Por variable: prod la tiene prendida (db_deletion_protection); dev y test se apagan con destroy
  #checkov:skip=CKV_AWS_157:Multi-AZ duplica el costo de la instancia; para el obligatorio alcanza con una sola zona y backups automáticos
  #checkov:skip=CKV_AWS_118:Enhanced monitoring necesita un rol de monitoreo propio y Academy no deja crear roles
  #checkov:skip=CKV_AWS_354:Performance Insights se encripta con la clave administrada por AWS; una clave KMS propia suma costo
  #checkov:skip=CKV_AWS_161:IAM auth necesita una política con rds-db:connect y un usuario con el rol rds_iam; Academy no deja crear políticas y la app entra con usuario y contraseña
  #checkov:skip=CKV2_AWS_69:catalog y orders traen sslmode=disable en su código y la app se usa tal cual; RDS está en subnets privadas y solo acepta a los servicios
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

  # Logs de PostgreSQL en CloudWatch, para investigar errores sin entrar a la base.
  # El log group lo crea Terraform (abajo) para que tenga retención y se borre con el destroy.
  enabled_cloudwatch_logs_exports = ["postgresql"]
  # Performance Insights con la retención gratuita (7 días)
  performance_insights_enabled          = true
  performance_insights_retention_period = 7
  # Parches menores de seguridad automáticos, en la ventana de mantenimiento
  auto_minor_version_upgrade = true
  # Los snapshots heredan los tags (proyecto, ambiente) y se pueden identificar
  copy_tags_to_snapshot = true

  backup_retention_period = var.backup_retention_days
  deletion_protection     = var.deletion_protection
  skip_final_snapshot     = var.skip_final_snapshot
  # Con fecha en el nombre, cada vez que se destruye la base queda un snapshot distinto:
  # con un nombre fijo, el segundo destroy falla con DBSnapshotAlreadyExists
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name}-postgres-final-${formatdate("YYYYMMDDhhmm", timestamp())}"
  apply_immediately         = true

  tags = merge(local.common_tags, { Name = "${var.name}-postgres" })

  depends_on = [aws_cloudwatch_log_group.postgresql]

  lifecycle {
    # timestamp() cambia en cada plan: el nombre se fija al crear la base y no se actualiza después
    ignore_changes = [final_snapshot_identifier]
  }
}
