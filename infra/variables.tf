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

variable "db_password_rotation_days" {
  type        = number
  description = "Cada cuántos días RDS rota la contraseña de la base. Después de una rotación hay que volver a desplegar los servicios"
  default     = 365
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

variable "admin_ingress_cidr" {
  type        = string
  description = "Origen permitido hacia el panel de admin en el ALB (por ejemplo 203.0.113.7/32). No se versiona: se pasa con -var"

  validation {
    condition     = can(cidrnetmask(var.admin_ingress_cidr))
    error_message = "Tiene que ser un CIDR IPv4 válido, por ejemplo 203.0.113.7/32."
  }
}

variable "service_cpu" {
  type        = number
  description = "Unidades de CPU de cada task de Fargate (256 = 0,25 vCPU)"
  default     = 256

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.service_cpu)
    error_message = "Fargate acepta 256, 512, 1024, 2048 o 4096."
  }
}

variable "service_memory" {
  type        = number
  description = "Memoria de cada task de Fargate en MiB (tiene que ser una combinación válida con la CPU)"
  default     = 512
}

variable "service_desired_count" {
  type        = number
  description = "Cantidad de tasks por servicio. Con 2 o más, ECS las reparte entre las zonas (lo intenta, no lo garantiza)"
  default     = 1

  validation {
    condition     = var.service_desired_count >= 1
    error_message = "Tiene que haber al menos 1 task por servicio."
  }
}

variable "log_retention_days" {
  type        = number
  description = "Días que se conservan los logs de los servicios y de la inicialización de la base en CloudWatch"
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365], var.log_retention_days)
    error_message = "CloudWatch solo acepta ciertos valores: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180 o 365."
  }
}


variable "alarm_email" {
  type        = string
  description = "Email que recibe las alarmas. No se versiona porque el repo es público: se pasa con -var o con el secret ALARM_EMAIL en los pipelines"
  sensitive   = true

  validation {
    condition     = can(regex("^[^@ ]+@[^@ ]+[.][^@ ]+$", var.alarm_email))
    error_message = "Tiene que ser un email válido, por ejemplo equipo@example.com."
  }
}
