# Dashboard de CloudWatch de Tero: disponibilidad, servicios ECS, ALBs y base de datos en una sola vista.
# Es lo primero que se abre cuando salta una alarma (ver docs/runbooks/).

locals {
  periodo = 300

  # Un widget de gráfico. Las métricas van en el formato de CloudWatch:
  # [namespace, métrica, dimensión, valor, ..., { opciones }]
  grafico = {
    view    = "timeSeries"
    stacked = false
    region  = var.region
    period  = local.periodo
  }

  servicios = sort(keys(var.service_names))

  # CPU y memoria en % (AWS/ECS); red y tasks corriendo de Container Insights
  metricas_servicio = {
    for metrica in ["CPUUtilization", "MemoryUtilization"] : metrica => [
      for s in local.servicios : ["AWS/ECS", metrica, "ClusterName", var.cluster_name, "ServiceName", var.service_names[s], { label = s }]
    ]
  }
  red_entrante = [
    for s in local.servicios : ["ECS/ContainerInsights", "NetworkRxBytes", "ClusterName", var.cluster_name, "ServiceName", var.service_names[s], { label = "${s} entrada" }]
  ]
  red_saliente = [
    for s in local.servicios : ["ECS/ContainerInsights", "NetworkTxBytes", "ClusterName", var.cluster_name, "ServiceName", var.service_names[s], { label = "${s} salida" }]
  ]
  tasks = [
    for s in local.servicios : ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", var.cluster_name, "ServiceName", var.service_names[s], { label = s }]
  ]

  alb = {
    for metrica, stat in {
      RequestCount              = "Sum"
      TargetResponseTime        = "p95"
      HTTPCode_Target_5XX_Count = "Sum"
      } : metrica => [
      for nombre, sufijo in var.load_balancers : ["AWS/ApplicationELB", metrica, "LoadBalancer", sufijo, { label = "ALB ${nombre}", stat = stat }]
    ]
  }

  salud_por_servicio = [
    for s in var.health_checked_services : ["Tero/Availability", "Healthy", "Service", s, { label = s, stat = "Minimum" }]
  ]
}

resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = var.name

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "text", x = 0, y = 0, width = 24, height = 2
        properties = {
          markdown = "# Tero (${var.name})\nSi salta una alarma, seguir su runbook: [disponibilidad](https://github.com/nicolasamoroso/Tero/blob/main/docs/runbooks/disponibilidad.md) · [rendimiento](https://github.com/nicolasamoroso/Tero/blob/main/docs/runbooks/rendimiento.md) · [recursos](https://github.com/nicolasamoroso/Tero/blob/main/docs/runbooks/recursos.md). Las líneas horizontales son los umbrales de las alarmas."
        }
      },

      # Disponibilidad: lo publica la Lambda health-checker cada 5 minutos
      {
        type = "metric", x = 0, y = 2, width = 12, height = 6
        properties = merge(local.grafico, {
          title       = "Disponibilidad (% de servicios sanos)"
          metrics     = [["Tero/Availability", "Availability", { label = "Disponibilidad", stat = "Minimum" }]]
          yAxis       = { left = { min = 0, max = 100 } }
          annotations = { horizontal = [{ label = "Todos sanos", value = 100 }] }
        })
      },
      {
        type = "metric", x = 12, y = 2, width = 12, height = 6
        properties = merge(local.grafico, {
          title   = "Health check por servicio (1 = sano, 0 = caído)"
          metrics = local.salud_por_servicio
          yAxis   = { left = { min = 0, max = 1 } }
        })
      },

      # Servicios ECS
      {
        type = "metric", x = 0, y = 8, width = 12, height = 6
        properties = merge(local.grafico, {
          title       = "CPU por servicio (%)"
          metrics     = local.metricas_servicio["CPUUtilization"]
          stat        = "Average"
          yAxis       = { left = { min = 0, max = 100 } }
          annotations = { horizontal = [{ label = "Alarma de CPU", value = var.cpu_threshold_percent }] }
        })
      },
      {
        type = "metric", x = 12, y = 8, width = 12, height = 6
        properties = merge(local.grafico, {
          title   = "Memoria por servicio (%)"
          metrics = local.metricas_servicio["MemoryUtilization"]
          stat    = "Average"
          yAxis   = { left = { min = 0, max = 100 } }
        })
      },
      {
        type = "metric", x = 0, y = 14, width = 12, height = 6
        properties = merge(local.grafico, {
          title   = "Red por servicio (bytes/s)"
          metrics = concat(local.red_entrante, local.red_saliente)
          stat    = "Average"
        })
      },
      {
        type = "metric", x = 12, y = 14, width = 12, height = 6
        properties = merge(local.grafico, {
          title   = "Tasks corriendo por servicio"
          metrics = local.tasks
          stat    = "Average"
          yAxis   = { left = { min = 0 } }
        })
      },

      # ALBs: el público (ui y admin) y el interno (catalog, carts, orders y checkout)
      {
        type = "metric", x = 0, y = 20, width = 8, height = 6
        properties = merge(local.grafico, {
          title   = "Requests por ALB"
          metrics = local.alb["RequestCount"]
        })
      },
      {
        type = "metric", x = 8, y = 20, width = 8, height = 6
        properties = merge(local.grafico, {
          title       = "Tiempo de respuesta p95 (s)"
          metrics     = local.alb["TargetResponseTime"]
          yAxis       = { left = { min = 0 } }
          annotations = { horizontal = [{ label = "Alarma de p95", value = var.response_time_p95_seconds }] }
        })
      },
      {
        type = "metric", x = 16, y = 20, width = 8, height = 6
        properties = merge(local.grafico, {
          title       = "Respuestas 5XX de los servicios"
          metrics     = local.alb["HTTPCode_Target_5XX_Count"]
          yAxis       = { left = { min = 0 } }
          annotations = { horizontal = [{ label = "Alarma de 5XX", value = var.error_5xx_threshold }] }
        })
      },

      # Base de datos
      {
        type = "metric", x = 0, y = 26, width = 12, height = 6
        properties = merge(local.grafico, {
          title   = "RDS: CPU (%)"
          metrics = [["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.db_instance_id, { label = "CPU" }]]
          stat    = "Average"
          yAxis   = { left = { min = 0, max = 100 } }
        })
      },
      {
        type = "metric", x = 12, y = 26, width = 12, height = 6
        properties = merge(local.grafico, {
          title   = "RDS: conexiones abiertas"
          metrics = [["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", var.db_instance_id, { label = "Conexiones" }]]
          stat    = "Average"
          yAxis   = { left = { min = 0 } }
        })
      },
    ]
  })
}
