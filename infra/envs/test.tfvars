environment = "test"
vpc_cidr    = "10.20.0.0/16"

# Servicios: igual que dev; test valida que la imagen funcione antes de prod
service_cpu           = 256
service_memory        = 512
service_desired_count = 1
log_retention_days    = 14

# Base y Redis: como dev
db_instance_class            = "db.t3.micro"
cache_node_type              = "cache.t3.micro"
db_deletion_protection       = false
db_skip_final_snapshot       = true
secrets_recovery_window_days = 0
