module "cache" {
  source = "./modules/cache"

  name              = "${var.project}-${var.environment}"
  subnet_ids        = module.network.private_subnet_ids
  security_group_id = module.network.redis_security_group_id
  node_type         = var.cache_node_type
}
