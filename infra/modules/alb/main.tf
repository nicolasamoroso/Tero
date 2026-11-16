# ALB público de Tero: la UI en el puerto 80 y el panel de admin en otro puerto,
# restringido por IP en el security group del ALB.

locals {
  common_tags = merge(var.tags, { Module = "alb" })
}

resource "aws_lb" "this" {
  name               = "${var.name}-alb"
  load_balancer_type = "application"
  internal           = false
  subnets            = var.subnet_ids
  security_groups    = [var.security_group_id]

  tags = merge(local.common_tags, { Name = "${var.name}-alb" })
}

# Fargate con awsvpc se registra por IP, por eso target_type = "ip"
resource "aws_lb_target_group" "this" {
  for_each = toset(["ui", "admin"])

  name                 = "${var.name}-${each.key}"
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

  tags = merge(local.common_tags, { Name = "${var.name}-${each.key}" })
}

resource "aws_lb_listener" "ui" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this["ui"].arn
  }
}

resource "aws_lb_listener" "admin" {
  load_balancer_arn = aws_lb.this.arn
  port              = var.admin_listener_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this["admin"].arn
  }
}

# El panel de admin solo se abre desde el origen indicado. La UI (puerto 80)
# usa la regla que ya define el módulo network.
resource "aws_vpc_security_group_ingress_rule" "admin" {
  security_group_id = var.security_group_id
  description       = "Panel de admin, solo desde el origen permitido"
  ip_protocol       = "tcp"
  from_port         = var.admin_listener_port
  to_port           = var.admin_listener_port
  cidr_ipv4         = var.admin_ingress_cidr
}
