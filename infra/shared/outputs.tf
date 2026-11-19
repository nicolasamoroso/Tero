output "ecr_repository_urls" {
  description = "URL de cada repositorio ECR por servicio, compartidos por dev, test y prod"
  value       = module.ecr.repository_urls
}
