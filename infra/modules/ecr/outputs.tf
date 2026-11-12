output "repository_urls" {
  description = "URL de cada repositorio por servicio: destino del push del CD y origen de la imagen en las task definitions de ECS"
  value       = { for name, repo in aws_ecr_repository.this : name => repo.repository_url }
}

output "repository_arns" {
  description = "ARN de cada repositorio por servicio, para permisos o políticas"
  value       = { for name, repo in aws_ecr_repository.this : name => repo.arn }
}
