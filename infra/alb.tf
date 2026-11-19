module "alb" {
  source = "./modules/alb"

  name               = "${var.project}-${var.environment}"
  vpc_id             = module.network.vpc_id
  subnet_ids         = module.network.public_subnet_ids
  security_group_id  = module.network.alb_security_group_id
  admin_ingress_cidr = var.admin_ingress_cidr
}
