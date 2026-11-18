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
  description = "Subnets del ALB interno (mínimo 2, en zonas distintas)"
}

variable "security_group_id" {
  type        = string
  description = "Security group del ALB interno (módulo network)"
}

variable "client_security_group_id" {
  type        = string
  description = "Security group de los servicios que llaman al ALB interno"
}

variable "services" {
  type        = map(number)
  description = "Servicio => puerto del listener en el ALB interno"
}

variable "container_port" {
  type        = number
  description = "Puerto en el que escuchan los servicios"
  default     = 8080
}

variable "tags" {
  type        = map(string)
  description = "Tags adicionales"
  default     = {}
}
