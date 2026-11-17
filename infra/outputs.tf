output "lab_role_arn" {
  description = "ARN del LabRole, que se usa como task role y execution role de ECS"
  value       = data.aws_iam_role.lab.arn
}

output "vpc_id" {
  description = "ID de la VPC del ambiente"
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "Subnets públicas (ALB y Fargate)"
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Subnets privadas (RDS y Redis)"
  value       = module.network.private_subnet_ids
}

output "db_endpoint" {
  description = "Host de PostgreSQL del ambiente"
  value       = module.database.endpoint
}

output "db_master_user_secret_arn" {
  description = "ARN del secreto con la contraseña de la base (lo referencia la task definition de ECS)"
  value       = module.database.master_user_secret_arn
}

output "redis_url" {
  description = "URL de Redis para checkout (RETAIL_CHECKOUT_PERSISTENCE_REDIS_URL)"
  value       = module.cache.url
}

output "admin_password_secret_arn" {
  description = "ARN del secreto ADMIN_PASSWORD (el valor se carga fuera de Terraform)"
  value       = aws_secretsmanager_secret.admin_password.arn
}

output "admin_jwt_secret_arn" {
  description = "ARN del secreto ADMIN_JWT_SECRET (el valor se carga fuera de Terraform)"
  value       = aws_secretsmanager_secret.admin_jwt_secret.arn
}

output "alb_url" {
  description = "URL pública de la UI"
  value       = module.alb.url
}

output "alb_admin_url" {
  description = "URL del panel de admin (restringida por IP)"
  value       = module.alb.admin_url
}
