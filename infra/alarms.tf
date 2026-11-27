module "alarms" {
  source = "./modules/alarms"

  name        = "${var.project}-${var.environment}"
  alarm_email = var.alarm_email

  load_balancers = {
    publico = module.alb.arn_suffix
    interno = module.internal_alb.arn_suffix
  }

  # ui y admin están detrás del ALB público; catalog, carts, orders y checkout, detrás del interno
  target_groups = merge(
    { for name, tg in module.alb.target_group_arn_suffixes : name => {
      load_balancer = module.alb.arn_suffix
      target_group  = tg
    } },
    { for name, tg in module.internal_alb.target_group_arn_suffixes : name => {
      load_balancer = module.internal_alb.arn_suffix
      target_group  = tg
    } },
  )

  cluster_name  = module.ecs_cluster.cluster_name
  service_names = { for name, svc in module.service : name => svc.service_name }
}
