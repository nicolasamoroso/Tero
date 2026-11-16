resource "aws_ecs_cluster" "this" {
  name = var.name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_service_discovery_http_namespace" "this" {
  name        = var.name
  description = "Namespace de Service Connect para ${var.name}"
}
