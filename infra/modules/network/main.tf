# Red de Tero: VPC con 2 subnets públicas (ALB y tasks de Fargate) y 2 privadas
# (RDS y Redis), repartidas en 2 zonas. No hay NAT Gateway por costo, ver
# docs/adr/0001-sin-nat-gateway.md

locals {
  common_tags = merge(var.tags, { Module = "network" })
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, { Name = "${var.name}-vpc" })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, { Name = "${var.name}-igw" })
}

# Subnets: las públicas ocupan los bloques /24 0 y 1; las privadas, el 10 y el 11
resource "aws_subnet" "public" {
  count = length(var.azs)

  vpc_id            = aws_vpc.this.id
  availability_zone = var.azs[count.index]
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  # Fargate recibe su IP pública desde el servicio de ECS (assign_public_ip),
  # no desde la subnet, así que acá queda apagado
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, { Name = "${var.name}-public-${var.azs[count.index]}", Tier = "public" })
}

resource "aws_subnet" "private" {
  count = length(var.azs)

  vpc_id            = aws_vpc.this.id
  availability_zone = var.azs[count.index]
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)

  tags = merge(local.common_tags, { Name = "${var.name}-private-${var.azs[count.index]}", Tier = "private" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(local.common_tags, { Name = "${var.name}-public-rt" })
}

# Sin ruta a Internet: solo tráfico local de la VPC
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, { Name = "${var.name}-private-rt" })
}

resource "aws_route_table_association" "public" {
  count = length(var.azs)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count = length(var.azs)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ---------------------------------------------------------------------------
# Security groups: ALB -> servicios -> RDS y Redis
# ---------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "${var.name}-alb"
  description = "Load balancer publico de Tero"
  vpc_id      = aws_vpc.this.id

  tags = merge(local.common_tags, { Name = "${var.name}-alb-sg" })
}

resource "aws_security_group" "services" {
  name        = "${var.name}-services"
  description = "Servicios de Tero en ECS Fargate"
  vpc_id      = aws_vpc.this.id

  tags = merge(local.common_tags, { Name = "${var.name}-services-sg" })
}

resource "aws_security_group" "rds" {
  name        = "${var.name}-rds"
  description = "Base de datos PostgreSQL"
  vpc_id      = aws_vpc.this.id

  tags = merge(local.common_tags, { Name = "${var.name}-rds-sg" })
}

resource "aws_security_group" "redis" {
  name        = "${var.name}-redis"
  description = "Redis"
  vpc_id      = aws_vpc.this.id

  tags = merge(local.common_tags, { Name = "${var.name}-redis-sg" })
}

# ALB: recibe HTTP de Internet y solo habla con los servicios
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP desde el origen permitido"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = var.alb_ingress_cidr
}

resource "aws_vpc_security_group_egress_rule" "alb_to_services" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Hacia los servicios"
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
  referenced_security_group_id = aws_security_group.services.id
}

# Servicios: solo aceptan trafico del ALB y de los otros servicios.
# Tienen IP publica (no hay NAT), pero ninguna regla permite entrar desde Internet.
resource "aws_vpc_security_group_ingress_rule" "services_from_alb" {
  security_group_id            = aws_security_group.services.id
  description                  = "Desde el ALB"
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_ingress_rule" "services_from_services" {
  security_group_id            = aws_security_group.services.id
  description                  = "Entre servicios"
  ip_protocol                  = "tcp"
  from_port                    = var.container_port
  to_port                      = var.container_port
  referenced_security_group_id = aws_security_group.services.id
}

# Salida libre: hace falta para bajar imagenes de ECR y hablar con las APIs de AWS
resource "aws_vpc_security_group_egress_rule" "services_all" {
  security_group_id = aws_security_group.services.id
  description       = "Salida a Internet (ECR, CloudWatch, Secrets Manager)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# RDS y Redis: solo desde los servicios y sin salida (un SG sin reglas de egress la bloquea)
resource "aws_vpc_security_group_ingress_rule" "rds_from_services" {
  security_group_id            = aws_security_group.rds.id
  description                  = "PostgreSQL desde los servicios"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.services.id
}

resource "aws_vpc_security_group_ingress_rule" "redis_from_services" {
  security_group_id            = aws_security_group.redis.id
  description                  = "Redis desde los servicios"
  ip_protocol                  = "tcp"
  from_port                    = 6379
  to_port                      = 6379
  referenced_security_group_id = aws_security_group.services.id
}
