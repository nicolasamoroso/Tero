module "database" {
  source = "./modules/database"

  name                = "${var.project}-${var.environment}"
  subnet_ids          = module.network.private_subnet_ids
  security_group_id   = module.network.rds_security_group_id
  instance_class      = var.db_instance_class
  deletion_protection = var.db_deletion_protection
  skip_final_snapshot = var.db_skip_final_snapshot
  log_retention_days  = var.log_retention_days
}
