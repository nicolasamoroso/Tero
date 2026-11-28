module "dashboard" {
  source = "./modules/dashboard"

  name         = "${var.project}-${var.environment}"
  region       = var.region
  cluster_name = module.ecs_cluster.cluster_name

  service_names = { for name, svc in module.service : name => svc.service_name }

  load_balancers = {
    publico = module.alb.arn_suffix
    interno = module.internal_alb.arn_suffix
  }

  db_instance_id = module.database.identifier

  # El health-checker chequea los servicios del ALB interno
  health_checked_services = sort(keys(module.internal_alb.target_group_arn_suffixes))
}
