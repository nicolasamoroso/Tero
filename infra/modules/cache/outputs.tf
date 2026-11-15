output "endpoint" {
  description = "Host de Redis"
  value       = aws_elasticache_cluster.this.cache_nodes[0].address
}

output "port" {
  description = "Puerto de Redis"
  value       = aws_elasticache_cluster.this.port
}

output "url" {
  description = "URL para RETAIL_CHECKOUT_PERSISTENCE_REDIS_URL de checkout"
  value       = "redis://${aws_elasticache_cluster.this.cache_nodes[0].address}:${aws_elasticache_cluster.this.port}"
}
