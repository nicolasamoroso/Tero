environment = "dev"
vpc_cidr    = "10.10.0.0/16"

# Servicios: lo mínimo, una task por servicio
service_cpu           = 256
service_memory        = 512
service_desired_count = 1
log_retention_days    = 7

# Base y Redis: lo más chico; se destruye y se recrea seguido
db_instance_class            = "db.t3.micro"
cache_node_type              = "cache.t3.micro"
db_deletion_protection       = false
db_skip_final_snapshot       = true
secrets_recovery_window_days = 0
