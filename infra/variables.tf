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
}

variable "vpc_cidr" {
  type        = string
  description = "Bloque CIDR de la VPC del ambiente"
}
