# Inicialización de la base: una task one-off de Fargate que corre init-db.sql con psql.
# RDS está en subnets privadas, por eso se corre dentro de la VPC y no desde la
# máquina de cada uno. Se ejecuta con scripts/init-db.sh, una vez por ambiente.

resource "aws_cloudwatch_log_group" "db_init" {
  #checkov:skip=CKV_AWS_158:CloudWatch ya encripta los logs con claves administradas por AWS; una clave KMS propia suma costo
  #checkov:skip=CKV_AWS_338:La retención se define por ambiente (log_retention_days); un año de logs en Academy es costo sin uso
  name              = "/ecs/${var.project}-${var.environment}/db-init"
  retention_in_days = var.log_retention_days
}

resource "aws_ecs_task_definition" "db_init" {
  #checkov:skip=CKV_AWS_249:Academy solo permite usar LabRole, así que el rol de ejecución y el de la task son el mismo
  family                   = "${var.project}-${var.environment}-db-init"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = data.aws_iam_role.lab.arn
  task_role_arn            = data.aws_iam_role.lab.arn

  container_definitions = jsonencode([
    {
      name       = "db-init"
      image      = "postgres:16.13"
      essential  = true
      entryPoint = ["sh", "-c"]
      # El script viaja en base64 y psql lo lee por stdin; tr saca los CR por si el archivo tiene CRLF
      command = ["echo \"$INIT_SQL_B64\" | base64 -d | tr -d '\\r' | psql -v ON_ERROR_STOP=1 -f -"]

      environment = [
        { name = "INIT_SQL_B64", value = filebase64("${path.root}/../init-db.sql") },
        { name = "PGHOST", value = module.database.endpoint },
        { name = "PGPORT", value = tostring(module.database.port) },
        { name = "PGUSER", value = module.database.username },
        { name = "PGDATABASE", value = module.database.db_name },
        { name = "PGSSLMODE", value = "require" },
      ]

      # La contraseña la genera RDS y llega desde Secrets Manager, nunca pasa por el código
      secrets = [
        { name = "PGPASSWORD", valueFrom = local.db_password },
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.db_init.name
          awslogs-region        = var.region
          awslogs-stream-prefix = "db-init"
        }
      }
    }
  ])
}

output "db_init_cluster" {
  description = "Cluster donde corre la task de inicialización de la base"
  value       = module.ecs_cluster.cluster_name
}

output "db_init_task_definition" {
  description = "Task definition de inicialización de la base"
  value       = aws_ecs_task_definition.db_init.family
}

output "db_init_subnets" {
  description = "Subnets (separadas por coma) donde corre la task"
  value       = join(",", module.network.public_subnet_ids)
}

output "db_init_security_group" {
  description = "Security group de la task (el de los servicios, que RDS permite)"
  value       = module.network.services_security_group_id
}

output "db_init_log_group" {
  description = "Log group con la salida de la inicialización"
  value       = aws_cloudwatch_log_group.db_init.name
}
