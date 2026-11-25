output "sns_topic_arn" {
  description = "ARN del tópico SNS de las alarmas (lo puede reusar la alarma de la Lambda de DEV-38)"
  value       = aws_sns_topic.alarms.arn
}

output "alarm_names" {
  description = "Nombres de todas las alarmas creadas"
  value = concat(
    values(aws_cloudwatch_metric_alarm.errores_5xx)[*].alarm_name,
    values(aws_cloudwatch_metric_alarm.tasks_no_sanas)[*].alarm_name,
    values(aws_cloudwatch_metric_alarm.latencia_p95)[*].alarm_name,
    values(aws_cloudwatch_metric_alarm.cpu)[*].alarm_name,
  )
}
