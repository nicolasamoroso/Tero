# Runbook: disponibilidad

Cubre dos alarmas, porque las dos significan "los usuarios reciben errores o hay un servicio caído":

| Alarma | Se dispara cuando | Por qué ese umbral |
|--|--|--|
| `tero-<ambiente>-<publico\|interno>-5xx` | Más de 5 respuestas 5XX de los servicios en 5 minutos, en el ALB público o en el interno | Un error suelto puede ser un request raro; más de 5 en 5 minutos ya es un patrón |
| `tero-<ambiente>-<servicio>-unhealthy` | Al menos una task del servicio no pasa el health check (`/health`) durante 2 minutos seguidos | 2 minutos evita avisar por una task que tarda en arrancar en un deploy |

El ALB público tiene ui y admin; el interno, catalog, carts, orders y checkout. Si salta la alarma del interno pero no la del público, el error está en un servicio de atrás y la ui lo puede estar escondiendo o mostrando como página de error.

## 1. Confirmar y medir el impacto (2 minutos)

- En CloudWatch → Alarms, mirar qué alarmas están en `In alarm` y desde cuándo.
- Abrir la tienda (`alb_url` en los outputs de Terraform). Si no carga, el impacto es total.
- Ver qué servicio falla y si sus tasks están corriendo:

```bash
aws ecs describe-services --cluster tero-dev --services ui catalog carts orders checkout admin \
  --query "services[].{servicio:serviceName,deseadas:desiredCount,corriendo:runningCount,deploy:deployments[0].rolloutState}" --output table
```

## 2. Encontrar la causa

| Qué ves | Causa probable | Dónde mirar |
|--|--|--|
| `corriendo` menor que `deseadas`, tasks que se reinician | El contenedor se cae al arrancar (falta una variable, no llega a la base o a Redis) | ECS → el servicio → Events, y los logs de la task |
| El deploy está en `IN_PROGRESS` o `FAILED` | Una imagen nueva que no arranca; el circuit breaker vuelve solo a la versión anterior | ECS → Deployments; Actions → el último run del CD |
| Tasks corriendo pero 5XX | Error de la aplicación o de una dependencia (RDS, Redis, otro servicio) | Logs del servicio |
| Solo catalog, con el chaos activo | Alguien activó `/chaos/status` o `/chaos/health` (prueba de DEV-42) | `GET /chaos/status` en catalog |

Logs de los últimos 15 minutos de un servicio:

```bash
aws logs tail /ecs/tero-dev/catalog --since 15m --follow
```

## 3. Mitigar

- **Fue un deploy:** si el circuit breaker no volvió solo a la versión anterior, la salida definitiva es revertir el commit en develop (`git revert`) y dejar que el CD despliegue. Si urge, se puede volver antes a la revisión anterior de la task definition, sabiendo que el próximo apply de Terraform la pisa:

```bash
aws ecs update-service --cluster tero-dev --service catalog --task-definition tero-dev-catalog:<revisión anterior>
```
- **Una task trabada:** forzar tasks nuevas con la misma imagen.

```bash
aws ecs update-service --cluster tero-dev --service catalog --force-new-deployment
```

- **La base o Redis no responden:** revisar en la consola de RDS y ElastiCache que estén `Available`. En Academy, si el lab se reinició, esperar a que vuelvan.
- **Chaos activo:** apagarlo (`DELETE /chaos/status` y `DELETE /chaos/health` en catalog).

## 4. Verificar y cerrar

- La alarma vuelve a `OK` sola (llega el mail de OK de SNS). La de 5XX puede tardar hasta 5 minutos, porque mira una ventana de 5 minutos.
- La tienda carga y se puede agregar un producto al carrito.
- Anotar en el canal del equipo qué pasó, la causa y qué se hizo.
