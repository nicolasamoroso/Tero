module "internal_alb" {
  source = "./modules/internal-alb"

  name                     = "${var.project}-${var.environment}"
  vpc_id                   = module.network.vpc_id
  subnet_ids               = module.network.private_subnet_ids
  security_group_id        = module.network.internal_alb_security_group_id
  client_security_group_id = module.network.services_security_group_id

  services = {
    catalog  = 8082
    carts    = 8083
    orders   = 8084
    checkout = 8085
  }
}
