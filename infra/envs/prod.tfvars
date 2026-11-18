environment = "prod"
vpc_cidr    = "10.30.0.0/16"

# Servicios: 2 tasks por servicio (una en cada zona) y más recursos
service_cpu           = 512
service_memory        = 1024
service_desired_count = 2
log_retention_days    = 30

# Base y Redis: mismo tamaño (límite de presupuesto de Academy), pero protegidos
db_instance_class            = "db.t3.micro"
cache_node_type              = "cache.t3.micro"
db_deletion_protection       = true
db_skip_final_snapshot       = false
secrets_recovery_window_days = 7
