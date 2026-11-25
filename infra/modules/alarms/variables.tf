variable "name" {
  type        = string
  description = "Prefijo para nombrar los recursos, por ejemplo tero-dev"
}

variable "alarm_email" {
  type        = string
  description = "Email que recibe las alarmas. Hay que confirmar la suscripción desde el mail que manda AWS"
  sensitive   = true
}

variable "load_balancers" {
  type        = map(string)
  description = "ALBs a vigilar: nombre corto => arn_suffix (por ejemplo publico => app/tero-dev-alb/abc123)"
}

variable "target_groups" {
  type = map(object({
    load_balancer = string
    target_group  = string
  }))
  description = "Target groups a vigilar por servicio: arn_suffix del ALB y del target group"
}

variable "cluster_name" {
  type        = string
  description = "Cluster ECS de los servicios"
}

variable "service_names" {
  type        = map(string)
  description = "Servicios ECS a vigilar: nombre corto => nombre del servicio en ECS"
}

variable "error_5xx_threshold" {
  type        = number
  description = "Cantidad de respuestas 5XX en 5 minutos a partir de la cual se dispara la alarma"
  default     = 5
}

variable "response_time_p95_seconds" {
  type        = number
  description = "Tiempo de respuesta p95, en segundos, a partir del cual se dispara la alarma"
  default     = 1
}

variable "cpu_threshold_percent" {
  type        = number
  description = "CPU promedio de un servicio, en %, que sostenida 10 minutos dispara la alarma"
  default     = 80
}

variable "tags" {
  type        = map(string)
  description = "Tags adicionales para todos los recursos"
  default     = {}
}
