# Alarmas de CloudWatch de Tero. Todas avisan por email a través de un tópico SNS,
# cuando se disparan y cuando vuelven a la normalidad. Cada una apunta a su runbook en docs/runbooks/.

locals {
  common_tags = merge(var.tags, { Module = "alarms" })
  runbooks    = "https://github.com/nicolasamoroso/Tero/blob/main/docs/runbooks"
}

resource "aws_sns_topic" "alarms" {
  #checkov:skip=CKV_AWS_26:CloudWatch no puede publicar en un tópico cifrado con la clave administrada aws/sns y una clave propia de KMS tiene costo mensual; los mensajes son avisos sin datos sensibles
  name = "${var.name}-alarmas"
  tags = merge(local.common_tags, { Name = "${var.name}-alarmas" })
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# Disponibilidad (1): los servicios responden errores 5XX
resource "aws_cloudwatch_metric_alarm" "errores_5xx" {
  for_each = var.load_balancers

  alarm_name        = "${var.name}-${each.key}-5xx"
  alarm_description = "Más de ${var.error_5xx_threshold} respuestas 5XX en 5 minutos en el ALB ${each.key}. Runbook: ${local.runbooks}/disponibilidad.md"

  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  dimensions          = { LoadBalancer = each.value }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.error_5xx_threshold
  # Sin errores la métrica no tiene datos: eso es estar bien
  treat_missing_data = "notBreaching"

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]
  tags          = local.common_tags
}

# Disponibilidad (2): el ALB ve tasks que no pasan el health check
resource "aws_cloudwatch_metric_alarm" "tasks_no_sanas" {
  for_each = var.target_groups

  alarm_name        = "${var.name}-${each.key}-unhealthy"
  alarm_description = "${each.key} tiene al menos una task que no pasa el health check durante 2 minutos. Runbook: ${local.runbooks}/disponibilidad.md"

  namespace   = "AWS/ApplicationELB"
  metric_name = "UnHealthyHostCount"
  dimensions = {
    LoadBalancer = each.value.load_balancer
    TargetGroup  = each.value.target_group
  }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]
  tags          = local.common_tags
}

# Rendimiento: el 5% de los requests más lentos tarda más de lo aceptable
resource "aws_cloudwatch_metric_alarm" "latencia_p95" {
  for_each = var.load_balancers

  alarm_name        = "${var.name}-${each.key}-p95"
  alarm_description = "El p95 del tiempo de respuesta del ALB ${each.key} supera ${var.response_time_p95_seconds} s en 5 minutos. Runbook: ${local.runbooks}/rendimiento.md"

  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  dimensions          = { LoadBalancer = each.value }
  extended_statistic  = "p95"
  period              = 300
  evaluation_periods  = 1
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.response_time_p95_seconds
  # Sin tráfico no hay tiempos de respuesta: no es un problema de rendimiento
  treat_missing_data = "notBreaching"

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]
  tags          = local.common_tags
}

# Recursos: un servicio usa casi toda su CPU de forma sostenida
resource "aws_cloudwatch_metric_alarm" "cpu" {
  for_each = var.service_names

  alarm_name        = "${var.name}-${each.key}-cpu"
  alarm_description = "${each.key} usa más de ${var.cpu_threshold_percent}% de CPU durante 10 minutos. Runbook: ${local.runbooks}/recursos.md"

  namespace   = "AWS/ECS"
  metric_name = "CPUUtilization"
  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = each.value
  }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  comparison_operator = "GreaterThanThreshold"
  threshold           = var.cpu_threshold_percent
  treat_missing_data  = "missing"

  alarm_actions = [aws_sns_topic.alarms.arn]
  ok_actions    = [aws_sns_topic.alarms.arn]
  tags          = local.common_tags
}
