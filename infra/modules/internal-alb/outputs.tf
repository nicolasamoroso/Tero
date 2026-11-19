output "dns_name" {
  description = "DNS interno del ALB (solo resuelve dentro de la VPC)"
  value       = aws_lb.this.dns_name
}

output "urls" {
  description = "URL de cada servicio a través del ALB interno"
  value       = { for name, port in var.services : name => "http://${aws_lb.this.dns_name}:${port}" }
}

# Depende de los listeners: un service de ECS no se puede crear con un target
# group que todavía no está asociado a un listener.
output "target_group_arns" {
  description = "ARN de los target groups por servicio"
  value       = { for name, tg in aws_lb_target_group.this : name => tg.arn }

  depends_on = [aws_lb_listener.this]
}
