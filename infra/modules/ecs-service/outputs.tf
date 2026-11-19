output "service_name" {
  description = "Nombre del servicio ECS"
  value       = aws_ecs_service.this.name
}

output "task_definition_arn" {
  description = "ARN de la task definition vigente del servicio"
  value       = aws_ecs_task_definition.this.arn
}

output "log_group_name" {
  description = "Nombre del log group de CloudWatch del servicio"
  value       = aws_cloudwatch_log_group.this.name
}
