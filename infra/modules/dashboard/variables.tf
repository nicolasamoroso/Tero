variable "name" {
  type        = string
  description = "Prefijo para nombrar el dashboard, por ejemplo tero-dev"
}

variable "region" {
  type        = string
  description = "Región de las métricas"
}

variable "cluster_name" {
  type        = string
  description = "Cluster ECS de los servicios"
}

variable "service_names" {
  type        = map(string)
  description = "Servicios ECS: nombre corto => nombre del servicio en ECS"
}

variable "load_balancers" {
  type        = map(string)
  description = "ALBs: nombre corto => arn_suffix (dimensión LoadBalancer)"
}

variable "db_instance_id" {
  type        = string
  description = "Identificador de la instancia RDS"
}

variable "health_checked_services" {
  type        = list(string)
  description = "Servicios que chequea el health-checker (los del ALB interno), para la métrica Healthy por servicio"
}

# Mismos umbrales que las alarmas (modules/alarms): se dibujan como línea horizontal en cada gráfico
variable "cpu_threshold_percent" {
  type        = number
  description = "Umbral de CPU de la alarma, en %"
  default     = 80
}

variable "response_time_p95_seconds" {
  type        = number
  description = "Umbral del p95 de la alarma, en segundos"
  default     = 1
}

variable "error_5xx_threshold" {
  type        = number
  description = "Umbral de respuestas 5XX en 5 minutos de la alarma"
  default     = 5
}
