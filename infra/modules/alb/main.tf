# ALB público de Tero: la UI en el puerto 80 y el panel de admin en otro puerto,
# restringido por IP en el security group del ALB.

locals {
  common_tags = merge(var.tags, { Module = "alb" })
}

resource "aws_lb" "this" {
  #checkov:skip=CKV_AWS_150:Sin protección contra borrado para poder apagar los ambientes con destroy y cuidar el presupuesto de Academy
  #checkov:skip=CKV_AWS_91:Los access logs necesitan un bucket S3 con política para ELB; los logs de cada servicio ya van a CloudWatch
  #checkov:skip=CKV2_AWS_20:Sin dominio propio no hay certificado de ACM, así que no hay listener HTTPS al que redirigir (ADR 0003)
  #checkov:skip=CKV2_AWS_28:WAF tiene costo fijo por web ACL y por regla; el ingreso ya está limitado por el security group
  name               = "${var.name}-alb"
  load_balancer_type = "application"
  internal           = false
  subnets            = var.subnet_ids
  security_groups    = [var.security_group_id]

  # Descarta los requests con headers HTTP inválidos en vez de pasarlos a los servicios
  drop_invalid_header_fields = true

  tags = merge(local.common_tags, { Name = "${var.name}-alb" })
}

# Fargate con awsvpc se registra por IP, por eso target_type = "ip"
resource "aws_lb_target_group" "this" {
  #checkov:skip=CKV_AWS_378:El ALB termina el tráfico y habla con las tasks dentro de la VPC; los contenedores sirven HTTP
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
  #checkov:skip=CKV_AWS_2:Sin dominio propio no hay certificado de ACM para un listener HTTPS (ADR 0003)
  #checkov:skip=CKV_AWS_103:Sin HTTPS no aplica la política de TLS
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this["ui"].arn
  }
}

resource "aws_lb_listener" "admin" {
  #checkov:skip=CKV_AWS_2:Sin dominio propio no hay certificado de ACM; el panel de admin queda limitado por IP en el security group (ADR 0003)
  #checkov:skip=CKV_AWS_103:Sin HTTPS no aplica la política de TLS
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
