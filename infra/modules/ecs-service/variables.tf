variable "name" {
  type        = string
  description = "Nombre del servicio. Es también el nombre DNS interno, por ejemplo catalog para http://catalog:8080"
}

variable "prefix" {
  type        = string
  description = "Prefijo del ambiente para nombrar la task definition y el log group, por ejemplo tero-dev"
}

variable "cluster_arn" {
  type        = string
  description = "ARN del cluster ECS donde corre el servicio"
}

variable "service_connect_namespace_arn" {
  type        = string
  description = "ARN del namespace de Service Connect del cluster"
}

variable "repository_url" {
  type        = string
  description = "URL del repositorio ECR con la imagen del servicio"
}

variable "image_tag" {
  type        = string
  description = "Tag de la imagen (el SHA del commit). También se expone al contenedor como APP_VERSION"
}

variable "role_arn" {
  type        = string
  description = "ARN del rol que se usa como task role y execution role (LabRole en AWS Academy)"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets donde corren las tasks"
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security groups de las tasks"
}

variable "assign_public_ip" {
  type        = bool
  description = "Si las tasks reciben IP pública. Hace falta en subnets públicas sin NAT para bajar la imagen de ECR"
  default     = true
}

variable "container_port" {
  type        = number
  description = "Puerto en el que escucha el contenedor"
  default     = 8080
}

variable "cpu" {
  type        = number
  description = "Unidades de CPU de la task de Fargate"
  default     = 256
}

variable "memory" {
  type        = number
  description = "Memoria de la task de Fargate en MiB"
  default     = 512
}

variable "desired_count" {
  type        = number
  description = "Cantidad de tasks que se mantienen corriendo"
  default     = 1
}

variable "environment" {
  type        = map(string)
  description = "Variables de entorno del contenedor"
  default     = {}
}

variable "secrets" {
  type        = map(string)
  description = "Secretos del contenedor. La clave es el nombre de la variable y el valor es el ARN en Secrets Manager (valueFrom)"
  default     = {}
}

variable "target_group_arn" {
  type        = string
  description = "ARN del target group del ALB. Si es null, el servicio no se registra en ningún balanceador"
  default     = null
}

variable "log_retention_days" {
  type        = number
  description = "Días que se conservan los logs en CloudWatch"
  default     = 7
}
