variable "name" {
  type        = string
  description = "Prefijo para nombrar los recursos, por ejemplo tero-dev"
}

variable "role_arn" {
  type        = string
  description = "Rol de ejecución de la Lambda. En Academy es LabRole, porque no se pueden crear roles"
}

variable "vpc_id" {
  type        = string
  description = "VPC del ambiente: la Lambda corre adentro para llegar al ALB interno"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets privadas donde corre la Lambda (las mismas del ALB interno)"
}

variable "internal_alb_security_group_id" {
  type        = string
  description = "Security group del ALB interno: se le agrega la entrada desde la Lambda"
}

variable "targets" {
  type = map(object({
    url  = string
    port = number
  }))
  description = "Servicios a chequear: nombre => URL del /health a través del ALB interno y su puerto"
}

variable "schedule" {
  type        = string
  description = "Cada cuánto corre la Lambda (expresión de EventBridge)"
  default     = "rate(5 minutes)"
}

variable "alarm_topic_arn" {
  type        = string
  description = "Tópico SNS de las alarmas (módulo alarms): la alarma de disponibilidad avisa ahí"
}

variable "log_retention_days" {
  type        = number
  description = "Días que se conservan los logs de la Lambda"
}

variable "tags" {
  type        = map(string)
  description = "Tags adicionales para todos los recursos"
  default     = {}
}

variable "api_rate_limit" {
  type        = number
  description = "Requests por segundo que acepta GET /status en promedio (throttling del stage)"
  default     = 1
}

variable "api_burst_limit" {
  type        = number
  description = "Requests que GET /status acepta de golpe antes de responder 429"
  default     = 2
}
