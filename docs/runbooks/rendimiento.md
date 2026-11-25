# Runbook: rendimiento

| Alarma | Se dispara cuando | Por qué ese umbral |
|--|--|--|
| `tero-<ambiente>-<publico\|interno>-p95` | El p95 del tiempo de respuesta (`TargetResponseTime`) supera 1 segundo en 5 minutos | El p95 mira al 5% de requests más lentos: el promedio esconde a los usuarios que esperan mucho. Más de 1 segundo ya se nota al navegar |

El p95 del ALB público incluye el tiempo que la ui espera a los servicios de atrás. Si sube solo el público, el problema está en la ui; si suben los dos, empezar por el interno.

## 1. Confirmar

- En CloudWatch → Alarms, ver la alarma y abrir su gráfico: ¿es un pico o sube de a poco?
- Ver si coincide con algo: un deploy, mucho tráfico (métrica `RequestCount` del ALB) o una prueba de carga (DEV-37).

## 2. Encontrar la causa

| Qué ves | Causa probable | Dónde mirar |
|--|--|--|
| La CPU de un servicio cerca del 100% | El servicio no da abasto (ver también el runbook de recursos) | ECS → el servicio → Metrics |
| `RequestCount` muy alto | Más tráfico del que soporta una task | CloudWatch, métricas del ALB |
| Solo catalog, con el chaos activo | Latencia inyectada con `/chaos/latency` (prueba de DEV-42) | `GET /chaos/status` en catalog |
| Las consultas tardan | La base está cargada | RDS → la instancia → Monitoring (CPU y conexiones) |

```bash
aws logs tail /ecs/tero-dev/catalog --since 15m
```

## 3. Mitigar

- **Chaos activo:** `DELETE /chaos/latency` en catalog.
- **Falta capacidad:** subir `service_desired_count` (o `service_cpu` y `service_memory`) en el tfvars del ambiente y aplicar con el pipeline de infra. Es un cambio versionado, no a mano en la consola.
- **Fue un deploy:** revertir el commit en develop, como en el runbook de disponibilidad.

## 4. Verificar y cerrar

- La alarma vuelve a `OK` (llega el mail de OK) cuando un período de 5 minutos queda por debajo de 1 segundo.
- Anotar en el canal del equipo la causa y lo que se hizo.
