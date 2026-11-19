# Secretos del panel de admin. Terraform crea solo el secreto vacío: el valor se carga
# aparte con el AWS CLI (ver README), así nunca está en el código ni en el state.
# ECS los referencia por ARN.

resource "aws_secretsmanager_secret" "admin_password" {
  name                    = "${var.project}/${var.environment}/admin-password"
  description             = "Contraseña del panel de admin (ADMIN_PASSWORD)"
  recovery_window_in_days = var.secrets_recovery_window_days
}

resource "aws_secretsmanager_secret" "admin_jwt_secret" {
  name                    = "${var.project}/${var.environment}/admin-jwt-secret"
  description             = "Secreto para firmar los tokens del panel de admin (ADMIN_JWT_SECRET)"
  recovery_window_in_days = var.secrets_recovery_window_days
}
