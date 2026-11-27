# Health-checker: una Lambda que cada 5 minutos llama al /health de cada servicio a través del
# ALB interno y publica la métrica Tero/Availability, con su propia alarma.
#
# Los hallazgos de Semgrep que quedan no bloquean (WARNING e INFO): el log group usa la clave
# administrada de CloudWatch y no hay X-Ray, con los mismos motivos que los skips de Checkov.
#
# Corre dentro de la VPC, en las subnets privadas, porque el ALB interno solo se alcanza desde
# ahí. Esas subnets no tienen salida a Internet (no hay NAT, ADR 0001), así que la métrica no se
# publica con la API de CloudWatch: se escribe en el log con el formato EMF y CloudWatch la arma.

locals {
  common_tags   = merge(var.tags, { Module = "health-checker" })
  function_name = "${var.name}-health-checker"
}

data "archive_file" "code" {
  type        = "zip"
  source_file = "${path.module}/lambda/handler.py"
  # Dentro de .terraform, que ya está en el .gitignore: el zip se arma en cada plan
  output_path = "${path.root}/.terraform/build/health-checker.zip"
}

# Security group propio: sin entrada, y solo sale hacia los puertos del ALB interno
resource "aws_security_group" "lambda" {
  name        = local.function_name
  description = "Lambda health-checker de Tero"
  vpc_id      = var.vpc_id
  tags        = merge(local.common_tags, { Name = local.function_name })
}

resource "aws_vpc_security_group_egress_rule" "to_internal_alb" {
  for_each = var.targets

  security_group_id            = aws_security_group.lambda.id
  description                  = "Health de ${each.key} en el ALB interno"
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
  referenced_security_group_id = var.internal_alb_security_group_id
}

resource "aws_vpc_security_group_ingress_rule" "internal_alb_from_lambda" {
  for_each = var.targets

  security_group_id            = var.internal_alb_security_group_id
  description                  = "${each.key} desde la Lambda health-checker"
  ip_protocol                  = "tcp"
  from_port                    = each.value.port
  to_port                      = each.value.port
  referenced_security_group_id = aws_security_group.lambda.id
}

# El log group se crea antes que la función, así tiene retención y se borra con el destroy
resource "aws_cloudwatch_log_group" "lambda" {
  #checkov:skip=CKV_AWS_158:CloudWatch ya encripta los logs con claves administradas por AWS; una clave KMS propia suma costo
  #checkov:skip=CKV_AWS_338:La retención se define por ambiente (log_retention_days); un año de logs en Academy es costo sin uso
  name              = "/aws/lambda/${local.function_name}"
  retention_in_days = var.log_retention_days
  tags              = local.common_tags
}

resource "aws_lambda_function" "this" {
  #checkov:skip=CKV_AWS_115:Academy limita la concurrencia de la cuenta a 10 y AWS exige dejar 10 sin reservar, así que no se puede reservar; además corre una vez cada 5 minutos
  #checkov:skip=CKV_AWS_116:Sin dead letter queue: si una ejecución falla, la siguiente corre a los 5 minutos y la alarma toma la falta de datos como caída
  #checkov:skip=CKV_AWS_272:Firmar el código necesita AWS Signer y un perfil de firma; el zip lo arma Terraform desde el repo, que ya pasa por los controles del CI
  #checkov:skip=CKV_AWS_50:Sin salida a Internet (no hay NAT, ADR 0001) las trazas de X-Ray no llegan al servicio; lo que hace la Lambda queda en su log
  function_name    = local.function_name
  description      = "Llama al /health de cada servicio y publica Tero/Availability"
  role             = var.role_arn
  runtime          = "python3.12"
  handler          = "handler.handler"
  filename         = data.archive_file.code.output_path
  source_code_hash = data.archive_file.code.output_base64sha256
  timeout          = 30
  memory_size      = 128

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  tags       = local.common_tags
  depends_on = [aws_cloudwatch_log_group.lambda]
}

# EventBridge la dispara cada 5 minutos
resource "aws_cloudwatch_event_rule" "schedule" {
  name                = local.function_name
  description         = "Dispara el health-checker de Tero"
  schedule_expression = var.schedule
  tags                = local.common_tags
}

# La lista de servicios viaja en el evento y no en variables de entorno: así la Lambda no
# guarda configuración que haya que cifrar con una clave propia
resource "aws_cloudwatch_event_target" "lambda" {
  rule  = aws_cloudwatch_event_rule.schedule.name
  arn   = aws_lambda_function.this.arn
  input = jsonencode({ targets = { for name, target in var.targets : name => target.url } })
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.schedule.arn
}

# La alarma propia de la Lambda: avisa si algún servicio no responde en dos chequeos seguidos.
# Sin datos cuenta como caída: si la Lambda deja de correr, tampoco hay quien vigile.
resource "aws_cloudwatch_metric_alarm" "availability" {
  alarm_name        = "${var.name}-availability"
  alarm_description = "Algún servicio no responde su /health en dos chequeos seguidos del health-checker (10 minutos). Runbook: https://github.com/nicolasamoroso/Tero/blob/main/docs/runbooks/disponibilidad.md"

  namespace           = "Tero/Availability"
  metric_name         = "Availability"
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 2
  comparison_operator = "LessThanThreshold"
  threshold           = 100
  treat_missing_data  = "breaching"

  alarm_actions = [var.alarm_topic_arn]
  ok_actions    = [var.alarm_topic_arn]
  tags          = local.common_tags
}
