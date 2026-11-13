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
