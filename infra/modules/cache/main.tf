# Redis de Tero en ElastiCache: checkout guarda ahí los checkouts en curso.
# Va en las subnets privadas, con un solo nodo (alcanza para el obligatorio y es lo más barato).

locals {
  common_tags = merge(var.tags, { Module = "cache" })
}

resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name}-redis"
  subnet_ids = var.subnet_ids

  tags = merge(local.common_tags, { Name = "${var.name}-redis" })
}

resource "aws_elasticache_cluster" "this" {
  cluster_id           = "${var.name}-redis"
  engine               = "redis"
  engine_version       = var.engine_version
  node_type            = var.node_type
  num_cache_nodes      = 1
  port                 = 6379
  parameter_group_name = "default.redis${split(".", var.engine_version)[0]}"

  subnet_group_name  = aws_elasticache_subnet_group.this.name
  security_group_ids = [var.security_group_id]
  apply_immediately  = true

  tags = merge(local.common_tags, { Name = "${var.name}-redis" })
}
