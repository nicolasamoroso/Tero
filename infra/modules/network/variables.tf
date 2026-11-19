variable "name" {
  type        = string
  description = "Prefijo para nombrar los recursos de red, por ejemplo tero-dev"
}

variable "vpc_cidr" {
  type        = string
  description = "Bloque CIDR de la VPC. Cada ambiente usa uno distinto para poder conectarlos en el futuro"
}

variable "azs" {
  type        = list(string)
  description = "Zonas de disponibilidad donde se reparten las subnets (mínimo 2, lo exigen el ALB y el subnet group de RDS)"

  validation {
    condition     = length(var.azs) >= 2
    error_message = "Hacen falta al menos 2 zonas de disponibilidad."
  }
}

variable "container_port" {
  type        = number
  description = "Puerto en el que escuchan los servicios de Tero (todos usan 8080)"
  default     = 8080
}

variable "alb_ingress_cidr" {
  type        = string
  description = "Origen permitido hacia el ALB en el puerto 80"
  default     = "0.0.0.0/0"
}

variable "tags" {
  type        = map(string)
  description = "Tags adicionales para todos los recursos"
  default     = {}
}
