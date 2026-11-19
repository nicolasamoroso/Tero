output "dns_name" {
  description = "DNS público del ALB"
  value       = aws_lb.this.dns_name
}

output "url" {
  description = "URL de la UI"
  value       = "http://${aws_lb.this.dns_name}"
}

output "admin_url" {
  description = "URL del panel de admin (solo accesible desde admin_ingress_cidr)"
  value       = "http://${aws_lb.this.dns_name}:${var.admin_listener_port}"
}

# Depende de los listeners: un service de ECS no se puede crear con un target
# group que todavía no está asociado a un listener.
output "target_group_arns" {
  description = "ARN de los target groups por servicio (ui y admin)"
  value       = { for name, tg in aws_lb_target_group.this : name => tg.arn }

  depends_on = [aws_lb_listener.ui, aws_lb_listener.admin]
}
