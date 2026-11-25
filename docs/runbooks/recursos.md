# Runbook: recursos

| Alarma | Se dispara cuando | Por qué ese umbral |
|--|--|--|
| `tero-<ambiente>-<servicio>-cpu` | El promedio de CPU del servicio supera el 80% durante 10 minutos (dos períodos de 5 minutos) | Con más del 80% sostenido, un pico de tráfico ya no tiene margen y empiezan a subir los tiempos de respuesta |

En dev y test cada task tiene 0,25 vCPU (`service_cpu = 256`), así que se llega al límite rápido.

## 1. Confirmar

- En ECS → el servicio → Metrics, ver la CPU y la memoria. ¿Subió con el tráfico o sin motivo?
- Ver si hay una prueba de carga corriendo (DEV-37) o un deploy reciente.

## 2. Encontrar la causa

| Qué ves | Causa probable |
|--|--|
| La CPU sube junto con `RequestCount` | Más tráfico: falta capacidad |
| CPU alta sin más tráfico, después de un deploy | Cambio en el código (un loop, una consulta pesada) |
| CPU alta y la task se reinicia | La task se queda sin recursos; revisar también la memoria |

```bash
aws logs tail /ecs/tero-dev/orders --since 15m
```

## 3. Mitigar

- **Más tráfico:** subir `service_desired_count` o `service_cpu` y `service_memory` en el tfvars del ambiente y aplicar con el pipeline de infra.
- **Fue un deploy:** revertir el commit en develop, como en el runbook de disponibilidad.

## 4. Verificar y cerrar

- La alarma vuelve a `OK` cuando un período de 5 minutos queda por debajo del 80%.
- Si hubo que subir recursos, dejarlo anotado: en prod tiene costo.
