variable "prefix" {
  type        = string
  description = "Prefijo del nombre de los repositorios (queda como <prefix>/<servicio>)"
}

variable "repositories" {
  type        = set(string)
  description = "Servicios para los que se crea un repositorio, uno por servicio"
}

variable "images_to_keep" {
  type        = number
  description = "Cantidad de imágenes que se conservan por repositorio; las más viejas se borran"
  default     = 20
}
