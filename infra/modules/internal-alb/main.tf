# ALB interno: los servicios se llaman entre sí a través de él, con un listener por servicio.
# Reemplaza a Service Connect, que en AWS Academy no se puede usar (no deja crear
# namespaces de Cloud Map).

locals {
  common_tags = merge(var.tags, { Module = "internal-alb" })
}

resource "aws_lb" "this" {
  name               = "${var.name}-int"
  load_balancer_type = "application"
  internal           = true
  subnets            = var.subnet_ids
  security_groups    = [var.security_group_id]

  tags = merge(local.common_tags, { Name = "${var.name}-int" })
}

resource "aws_lb_target_group" "this" {
  for_each = var.services

  name                 = "${var.name}-int-${each.key}"
  port                 = var.container_port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = var.vpc_id
  deregistration_delay = 30

  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = merge(local.common_tags, { Name = "${var.name}-int-${each.key}" })
}

resource "aws_lb_listener" "this" {
  for_each = var.services

  load_balancer_arn = aws_lb.this.arn
  port              = each.value
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[each.key].arn
  }
}

resource "aws_vpc_security_group_ingress_rule" "from_services" {
  for_each = var.services

  security_group_id            = var.security_group_id
  description                  = "${each.key} desde los servicios"
  ip_protocol                  = "tcp"
  from_port                    = each.value
  to_port                      = each.value
  referenced_security_group_id = var.client_security_group_id
}
