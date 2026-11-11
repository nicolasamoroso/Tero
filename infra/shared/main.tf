provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "tero"
      Stack     = "shared"
      ManagedBy = "terraform"
    }
  }
}

module "ecr" {
  source = "../modules/ecr"

  prefix       = "tero"
  repositories = ["ui", "catalog", "cart", "orders", "checkout", "admin"]
}
