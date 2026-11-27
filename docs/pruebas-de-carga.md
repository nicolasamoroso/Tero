# Prueba de carga con k6

Con 10 usuarios simultáneos durante 3 minutos, dev respondió todo sin errores y con un p95 de 202 ms medido desde el cliente (13 ms del lado del servidor). Pasaron todos los umbrales, ninguna alarma se disparó y la CPU más alta fue 14,5% (ui).

- **Script:** `tests/k6/carga.js`
- **Ambiente:** dev, el 27/11/2026 de 22:39 a 22:42 UTC, con 1 task por servicio (0,25 vCPU y 512 MiB cada una). Dev corría la imagen `da504dc` y, en catalog, el arreglo de la contraseña de DEV-38 (todavía sin mergear).
- **Datos que deja:** cada carrito se vacía al final, pero las compras quedan como órdenes en la base de dev (unas 80 por corrida, de clientes `k6-...`).
- **Imagen:** `grafana/k6:1.4.2`, corrida desde Montevideo contra el ALB público de us-east-1.

## Qué hace cada usuario virtual

Lo mismo que un cliente, en este orden. Así la carga pasa por los 5 servicios:

1. Lista el catálogo y abre un producto al azar (ui → catalog).
2. Lo agrega al carrito y mira el carrito (ui → carts).
3. Uno de cada cinco completa la compra: carga el checkout y lo confirma (ui → checkout → orders).
4. Vacía el carrito, para no acumular datos de prueba.

Entre paso y paso espera 1 segundo, como alguien que navega. La carga sube a 10 usuarios en 30 segundos, se queda 2 minutos y baja en 30 segundos. Es poca a propósito: las tasks de dev son las más chicas y el presupuesto de Academy es compartido.

## Umbrales

Son los mismos criterios que las alarmas (DEV-41): si se pasan en la prueba, en el ambiente saltaría la alarma.

| Umbral | Criterio | Resultado |
|--|--|--|
| `http_req_duration` p95 | < 1000 ms | **201,79 ms** ✓ |
| p95 del paso catálogo | < 1000 ms | 201,87 ms ✓ |
| p95 del paso carrito | < 1000 ms | 200,24 ms ✓ |
| p95 del paso compra | < 1500 ms | 203,58 ms ✓ |
| `http_req_failed` (errores) | < 1% | **0%** (0 de 2137) ✓ |
| `checks` | > 99% | **100%** (2137 de 2137) ✓ |

## Resultados

| Métrica | Valor |
|--|--|
| Requests | 2137 (11,6 por segundo) |
| Recorridos completos | 397, ninguno cortado |
| Tiempo de respuesta medido por k6 | promedio 159 ms, mediana 152 ms, p90 177 ms, p95 202 ms, máximo 498 ms |
| `TargetResponseTime` p95 del ALB público (CloudWatch) | 13 ms |
| `TargetResponseTime` p95 del ALB interno (CloudWatch) | 7 ms |
| CPU máxima por servicio | ui 14,5% · carts 4,0% · checkout 3,2% · catalog 1,5% · orders 0,2% |
| Alarmas en ALARM durante la prueba | ninguna |
| Lambda health-checker (`Tero/Availability`) | 100% |

## Qué se concluye

- **El tiempo que mide k6 es casi todo red.** El mínimo fue 141 ms y el servidor tarda 13 ms: la diferencia es el viaje de ida y vuelta de Montevideo a us-east-1. Para los usuarios de la tienda importa el número de k6; para saber si la app aguanta importa el de CloudWatch.
- **Con esta carga sobra capacidad:** el servicio más exigido (ui, que recibe todos los requests) no pasó del 15% de CPU. Ninguna alarma de rendimiento o de recursos estuvo cerca de dispararse.
- **El cuello de botella esperable es ui**, porque todo pasa por ella. Si se quisiera saber el límite real, el siguiente paso es subir los usuarios hasta que el p95 pase 1 segundo o la CPU de ui pase 80% (y ahí deberían saltar las alarmas `p95` y `cpu`).

## Cómo correrla

Desde la raíz del repo, con dev levantado (Git Bash):

```bash
BASE_URL=$(terraform -chdir=infra output -raw alb_url)
docker run --rm -i -e BASE_URL="$BASE_URL" grafana/k6:1.4.2 run - < tests/k6/carga.js
```

Si algún umbral no se cumple, k6 termina con código distinto de 0 y marca en rojo cuál falló.
