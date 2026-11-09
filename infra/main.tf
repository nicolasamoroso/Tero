provider "aws" {
  region = var.region
}

data "aws_iam_role" "lab" {
  name = "LabRole"
}
