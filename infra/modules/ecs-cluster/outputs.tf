output "cluster_arn" {
  description = "ARN del cluster ECS"
  value       = aws_ecs_cluster.this.arn
}

output "cluster_name" {
  description = "Nombre del cluster ECS"
  value       = aws_ecs_cluster.this.name
}

output "service_connect_namespace_arn" {
  description = "ARN del namespace de Service Connect, para que los servicios se encuentren por nombre"
  value       = aws_service_discovery_http_namespace.this.arn
}
