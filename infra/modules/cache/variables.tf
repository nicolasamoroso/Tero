variable "name" {
  type        = string
  description = "Prefijo para nombrar los recursos, por ejemplo tero-dev"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets privadas donde va Redis"
}

variable "security_group_id" {
  type        = string
  description = "Security group de Redis (del módulo network): solo acepta el puerto 6379 desde los servicios"
}

variable "node_type" {
  type        = string
  description = "Tamaño del nodo de ElastiCache"
  default     = "cache.t3.micro"
}

variable "engine_version" {
  type        = string
  description = "Versión de Redis (la que Academy creó por defecto en la prueba)"
  default     = "7.1"
}

variable "tags" {
  type        = map(string)
  description = "Tags adicionales para todos los recursos"
  default     = {}
}
