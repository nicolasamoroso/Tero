# Zonas fijas: si AWS agrega una zona nueva, la lista no cambia y la red no se mueve
data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "zone-name"
    values = ["${var.region}a", "${var.region}b"]
  }
}

module "network" {
  source = "./modules/network"

  name     = "${var.project}-${var.environment}"
  vpc_cidr = var.vpc_cidr
  azs      = slice(data.aws_availability_zones.available.names, 0, 2)
}
