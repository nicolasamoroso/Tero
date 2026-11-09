output "lab_role_arn" {
  description = "ARN del LabRole, que se usa como task role y execution role de ECS"
  value       = data.aws_iam_role.lab.arn
}
