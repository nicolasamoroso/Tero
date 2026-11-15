output "endpoint" {
  description = "Host de la base, sin el puerto (para DB_HOST y los *_PERSISTENCE_ENDPOINT de los servicios)"
  value       = aws_db_instance.this.address
}

output "port" {
  description = "Puerto de PostgreSQL"
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Base creada al levantar la instancia"
  value       = aws_db_instance.this.db_name
}

output "username" {
  description = "Usuario administrador de la base"
  value       = aws_db_instance.this.username
}

output "master_user_secret_arn" {
  description = "ARN del secreto de Secrets Manager con la contraseña de la base (lo lee ECS, nunca se guarda en el state)"
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}
