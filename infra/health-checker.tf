module "health_checker" {
  source = "./modules/health-checker"

  name                           = "${var.project}-${var.environment}"
  role_arn                       = data.aws_iam_role.lab.arn
  vpc_id                         = module.network.vpc_id
  subnet_ids                     = module.network.private_subnet_ids
  internal_alb_security_group_id = module.network.internal_alb_security_group_id
  alarm_topic_arn                = module.alarms.sns_topic_arn
  log_retention_days             = var.log_retention_days

  # Los servicios detrás del ALB interno. ui y admin están solo en el ALB público, que desde
  # las subnets privadas no se alcanza (no hay NAT); los cubren las alarmas de unhealthy.
  targets = {
    for name, port in local.internal_services : name => {
      url  = "${module.internal_alb.urls[name]}/health"
      port = port
    }
  }
}
