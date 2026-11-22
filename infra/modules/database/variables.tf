variable "name" {
  type        = string
  description = "Prefijo para nombrar los recursos, por ejemplo tero-dev"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets privadas donde va la base (mínimo 2 zonas, lo exige el subnet group de RDS)"
}

variable "security_group_id" {
  type        = string
  description = "Security group de RDS (del módulo network): solo acepta PostgreSQL desde los servicios"
}

variable "instance_class" {
  type        = string
  description = "Tamaño de la instancia de RDS"
  default     = "db.t3.micro"
}

variable "force_ssl" {
  type        = bool
  description = "Exigir SSL en las conexiones a la base. Va en false porque catalog y orders se conectan sin SSL"
  default     = false
}

variable "engine_version" {
  type        = string
  description = "Versión mayor de PostgreSQL. Es la misma que usa el compose (postgres:16)"
  default     = "16"
}

variable "allocated_storage" {
  type        = number
  description = "Espacio en disco, en GB"
  default     = 20
}

variable "db_name" {
  type        = string
  description = "Base que se crea al levantar la instancia. Las otras (catalogdb, cartdb) las crea la inicialización (DEV-17)"
  default     = "orders"
}

variable "username" {
  type        = string
  description = "Usuario administrador de la base. La contraseña la genera RDS y queda en Secrets Manager"
  default     = "retail_user"
}

variable "backup_retention_days" {
  type        = number
  description = "Días que se conservan los backups automáticos (0 los desactiva)"
  default     = 1
}

variable "log_retention_days" {
  type        = number
  description = "Días que se conservan los logs de PostgreSQL en CloudWatch"
  default     = 7
}

variable "deletion_protection" {
  type        = bool
  description = "Impide borrar la base con un destroy. Conviene en prod; en dev y test se deja apagado"
  default     = false
}

variable "skip_final_snapshot" {
  type        = bool
  description = "Si es true, al destruir no se guarda un snapshot final. En Academy se recrea todo; en prod conviene false"
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Tags adicionales para todos los recursos"
  default     = {}
}
