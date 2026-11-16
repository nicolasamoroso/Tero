variable "region" {
  type        = string
  description = "Región de AWS donde se despliega todo"
  default     = "us-east-1"
}

variable "project" {
  type        = string
  description = "Nombre del proyecto, se usa como prefijo de los recursos"
  default     = "tero"
}

variable "environment" {
  type        = string
  description = "Ambiente: dev, test o prod"

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "El ambiente debe ser dev, test o prod."
  }
}

variable "vpc_cidr" {
  type        = string
  description = "Bloque CIDR de la VPC del ambiente"
}

variable "db_instance_class" {
  type        = string
  description = "Tamaño de la instancia de RDS del ambiente"
  default     = "db.t3.micro"
}

variable "cache_node_type" {
  type        = string
  description = "Tamaño del nodo de ElastiCache del ambiente"
  default     = "cache.t3.micro"
}

variable "db_deletion_protection" {
  type        = bool
  description = "Impide destruir la base del ambiente. En prod conviene true"
  default     = false
}

variable "db_skip_final_snapshot" {
  type        = bool
  description = "Si es true, al destruir la base no se guarda un snapshot final. En prod conviene false"
  default     = true
}

variable "secrets_recovery_window_days" {
  type        = number
  description = "Días que AWS conserva un secreto borrado antes de eliminarlo (0 = al instante). En Academy va 0 para poder recrear con el mismo nombre; en prod conviene 7 o más"
  default     = 0

  validation {
    condition     = var.secrets_recovery_window_days == 0 || (var.secrets_recovery_window_days >= 7 && var.secrets_recovery_window_days <= 30)
    error_message = "Tiene que ser 0 o un valor entre 7 y 30 (lo que permite Secrets Manager)."
  }
}

variable "image_tag" {
  type        = string
  description = "Tag de las imágenes en ECR (el SHA del commit). Los tags son inmutables, no existe latest"
}

variable "admin_username" {
  type        = string
  description = "Usuario del panel de admin (ADMIN_USERNAME). No es secreto, la contraseña sí"
  default     = "admin"
}
