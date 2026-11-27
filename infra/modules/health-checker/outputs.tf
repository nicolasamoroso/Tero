output "function_name" {
  description = "Nombre de la Lambda health-checker"
  value       = aws_lambda_function.this.function_name
}

output "alarm_name" {
  description = "Nombre de la alarma de disponibilidad del health-checker"
  value       = aws_cloudwatch_metric_alarm.availability.alarm_name
}

output "status_url" {
  description = "URL pública de GET /status"
  value       = "${aws_apigatewayv2_stage.default.invoke_url}status"
}
