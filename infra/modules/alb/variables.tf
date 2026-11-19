variable "name" {
  type        = string
  description = "Prefijo de los recursos, por ejemplo tero-dev"
}

variable "vpc_id" {
  type        = string
  description = "VPC donde se crean los target groups"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets públicas del ALB (mínimo 2, en zonas distintas)"
}

variable "security_group_id" {
  type        = string
  description = "Security group del ALB (módulo network)"
}

variable "container_port" {
  type        = number
  description = "Puerto en el que escuchan los servicios"
  default     = 8080
}

variable "admin_listener_port" {
  type        = number
  description = "Puerto del listener del panel de admin"
  default     = 8081
}

variable "admin_ingress_cidr" {
  type        = string
  description = "Único origen que puede llegar al panel de admin, por ejemplo 203.0.113.7/32"

  validation {
    condition     = can(cidrnetmask(var.admin_ingress_cidr))
    error_message = "Tiene que ser un CIDR IPv4 válido, por ejemplo 203.0.113.7/32."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags adicionales"
  default     = {}
}
