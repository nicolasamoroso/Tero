output "vpc_id" {
  description = "ID de la VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "Bloque CIDR de la VPC"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs de las subnets públicas (ALB y tasks de Fargate), una por zona"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs de las subnets privadas (RDS y Redis), una por zona"
  value       = aws_subnet.private[*].id
}

output "alb_security_group_id" {
  description = "ID del security group del ALB"
  value       = aws_security_group.alb.id
}

output "services_security_group_id" {
  description = "ID del security group de los servicios en Fargate"
  value       = aws_security_group.services.id
}

output "rds_security_group_id" {
  description = "ID del security group de RDS"
  value       = aws_security_group.rds.id
}

output "redis_security_group_id" {
  description = "ID del security group de Redis"
  value       = aws_security_group.redis.id
}
