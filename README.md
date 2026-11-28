# Tero - Aplicación de ejemplo

Tero es una tienda en línea basada en microservicios. Permite explorar un catálogo de productos por categoría, gestionar un carrito de compras, realizar el checkout y consultar órdenes. Incluye un panel de administración para gestionar productos y ver órdenes.

> Los nombres técnicos (servicios `catalog`, `carts`, `orders`, `checkout`, variables `RETAIL_*`, usuario de base de datos `retail_user`) se mantienen tal como los dejó el equipo de desarrollo original.

## Requisitos previos

- [Docker](https://docs.docker.com/get-docker/) 24+
- [Docker Compose](https://docs.docker.com/compose/install/) v2.20+

Para desplegar en AWS (ver [Despliegue en AWS](#despliegue-en-aws)), además:

- [Terraform](https://developer.hashicorp.com/terraform/install) 1.10 o más nuevo
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) v2
- Credenciales de AWS con permisos sobre ECS, ECR, RDS, S3, ELB, Secrets Manager, CloudWatch y Lambda (en AWS Academy se usa el rol `LabRole`)

## Inicio rápido

Crear el archivo de variables a partir del ejemplo y completarlo:

```bash
cp .env.example .env
```

**Si ya tenías el proyecto levantado de antes:** Postgres guarda la contraseña solo cuando crea el volumen. Si cambiás `DB_PASSWORD`, borrá el volumen una vez para que se cree de nuevo (se pierden los datos locales):
```bash
docker compose down -v
```

```bash
docker compose up --build
```

| Servicio | URL                   |
|----------|-----------------------|
| Tienda   | http://localhost:8080 |
| Admin    | http://localhost:8081 |

Las credenciales del admin son las que pongas en `ADMIN_USERNAME` y `ADMIN_PASSWORD` en tu `.env`.

## Comandos útiles

```bash
# Detener los servicios
docker compose down

# Detener y eliminar volúmenes (resetear base de datos)
docker compose down -v

# Reconstruir un servicio específico
docker compose up --build <servicio>

# Ver logs de un servicio
docker compose logs -f <servicio>
```

## Tests

Cada servicio tiene tests unitarios que corren en el CI (`.github/workflows/ci.yml`) y generan el reporte de coverage que usa Sonar. No necesitan base de datos: usan las implementaciones en memoria de cada servicio (SQLite en catalog y orders).

| Servicio | Cómo correrlos (desde la carpeta del servicio) | Reporte de coverage |
|--|--|--|
| cart | `python -m venv .venv`, `.venv/Scripts/python -m pip install -r requirements-dev.txt` y `.venv/Scripts/python -m pytest --cov=app --cov-report=xml` | `coverage.xml` |
| catalog, orders | `go test ./... -coverpkg=./... -coverprofile=coverage.out` (sin Go instalado: `docker run --rm -v "$PWD:/src" -w /src golang:1.26.11 sh -c "go test ./..."`) | `coverage.out` |
| checkout | `node .yarn/releases/yarn-4.11.0.cjs test` | `coverage/lcov.info` |

`src/cart/requirements-dev.lock` fija con hashes todas las dependencias de test de cart. Hay que regenerarlo cuando cambian `requirements.txt` o `requirements-dev.txt`; si no, el CI prueba con versiones viejas. Desde `src/cart/` (con Python 3.12): `pip-compile --allow-unsafe --generate-hashes --output-file=requirements-dev.lock --pip-args='--only-binary=:all:' --strip-extras requirements-dev.txt`.

Lo mismo con `src/cart/requirements.lock`, que es lo que instala la imagen de cart: se regenera cuando cambia `requirements.txt`, con el mismo comando cambiando `requirements-dev` por `requirements`.

### Tests de integración (Postman)

`tests/postman/tero.postman_collection.json` recorre la tienda por el ALB público, como la UI: lista el catálogo, agrega un producto al carrito, carga el checkout, confirma la compra y verifica que la orden aparezca en orders. Cada corrida usa un cliente nuevo (`test-<timestamp>`). Hay un environment por ambiente en `tests/postman/environments/`; la URL se pasa al correrlo.

Corren después de cada deploy: en dev (`cd.yml`) y en test y prod (`promocion.yml`). El reporte JUnit queda como artefacto (`tests-integracion-<ambiente>`). Si fallan, el commit no se promueve: para ir a test tiene que haber pasado `deploy (dev)` y para ir a prod, `deploy (test)`.

A tener en cuenta:

- Para promover a prod, test tiene que estar levantado en cada release: la promoción exige que los tests hayan pasado ahí.
- Si dev estaba apagado al mergear, `deploy (dev)` queda en verde sin correr los tests, así que el gate hacia test no prueba nada. Los tests corren igual al desplegar en test, y eso es lo que exige prod.
- Los tests corren después del deploy: si fallan en prod, el job queda en rojo pero no vuelve a la versión anterior. Para volver atrás, ver el rollback en la sección 7.
- Cada corrida crea una orden real a nombre de "Juan Pérez" en la base del ambiente, también en prod.

También se puede importar la colección y el environment en Postman y correrla con Run collection (con `baseUrl` apuntando a la tienda). Para correrlos local desde la terminal, contra un ambiente levantado (con Docker y el `terraform init` de ese ambiente): `ENVIRONMENT=dev bash scripts/tests-integracion.sh`. Contra otra URL: `ENVIRONMENT=dev BASE_URL=http://localhost:8080 bash scripts/tests-integracion.sh`.

## Despliegue en AWS

La infraestructura está definida con Terraform en `infra/`. Los pasos se completan a medida que se agregan los módulos.

### 0. Credenciales de AWS

Toda la infraestructura vive en una única cuenta de AWS Academy, la de Nicolás. Quien quiera correr `terraform` desde su máquina necesita las credenciales de esa cuenta.

Desde el lab (AWS Details → AWS CLI) se copia el bloque de credenciales a `~/.aws/credentials`. Incluye `aws_session_token`. Para comprobar que funcionan:

```bash
aws sts get-caller-identity
```

### 1. Bucket del state de Terraform (se crea una sola vez, a mano)

El state de Terraform se guarda en S3. Es lo único que no se crea con Terraform, porque tiene que existir antes de poder usarlo.

**El bucket `tero-tfstate` ya existe en la cuenta compartida. Si se usan sus credenciales, se puede saltear este paso.**

```bash
B=tero-tfstate
aws s3api create-bucket --bucket "$B" --region us-east-1
aws s3api put-bucket-versioning --bucket "$B" --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket "$B" --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-public-access-block --bucket "$B" --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

El nombre de un bucket es único en todo AWS. Si `tero-tfstate` ya estuviera tomado, hay que elegir otro y cambiarlo en `infra/backend.tf`.

### 2. Inicializar Terraform para un ambiente

Cada ambiente (`dev`, `test`, `prod`) tiene su propio state, dentro del mismo bucket. La key se pasa al inicializar:

```bash
cd infra
terraform init -backend-config=envs/backend-dev.hcl
terraform plan -var-file=envs/dev.tfvars -var image_tag=<sha> -var admin_ingress_cidr=<tu-ip>/32 -var alarm_email=<tu-email>
```

Sin `-var-file`, Terraform pregunta el valor de `environment` y `vpc_cidr`. `image_tag` es el tag de las imágenes en ECR (el SHA del commit) y es obligatorio, porque los tags son inmutables y no existe `latest`.

Para cambiar de ambiente: `terraform init -reconfigure -backend-config=envs/backend-<ambiente>.hcl` y usar `-var-file=envs/<ambiente>.tfvars`.

### 3. Repositorios ECR (stack compartido, se aplica una sola vez)

Los repositorios de imágenes son los mismos para dev, test y prod, así que viven en un stack aparte (`infra/shared/`) con su propio state (`shared/terraform.tfstate`). Se aplica una sola vez, no por ambiente:

```bash
cd infra/shared
terraform init
terraform apply
```

Crea un repositorio por servicio (`tero/ui`, `tero/catalog`, `tero/cart`, `tero/orders`, `tero/checkout`, `tero/admin`) con tags inmutables y escaneo al hacer push. La política de limpieza borra las imágenes sin tag después de 1 día y conserva las últimas 30 por repositorio. Las URLs quedan en el output `ecr_repository_urls`.

Los repositorios no se pueden destruir si tienen imágenes (`force_delete = false`), para no perder las que usa prod. Para borrarlos a propósito: `terraform destroy -var force_delete=true`.

Como los tags son inmutables, las imágenes se publican con el SHA del commit, nunca con `latest`.

### 4. Levantar un ambiente (red, base de datos, Redis y secretos)

Desde `infra/`, con el ambiente elegido:

```bash
terraform init -reconfigure -backend-config=envs/backend-dev.hcl
terraform apply -var-file=envs/dev.tfvars -var image_tag=<sha> -var admin_ingress_cidr=<tu-ip>/32 -var alarm_email=<tu-email>
```

`admin_ingress_cidr` es el único origen que puede entrar al panel de admin (puerto 8081 del ALB). Tu IP: `curl -s https://checkip.amazonaws.com`. La UI es pública en el puerto 80. Las URLs salen en los outputs `alb_url` y `alb_admin_url`.

Crea la red, PostgreSQL en RDS y Redis en ElastiCache (los dos en las subnets privadas), los secretos del panel de admin, el cluster ECS y los seis servicios (ui, catalog, carts, orders, checkout y admin). Los servicios se llaman entre sí a través de un ALB interno, con un puerto por servicio (catalog 8082, carts 8083, orders 8084 y checkout 8085), porque AWS Academy no permite Service Connect. RDS y ElastiCache tardan unos 15 minutos en crearse.

**La contraseña de la base no pasa por Terraform:** RDS la genera y la guarda en Secrets Manager (output `db_master_user_secret_arn`).

**Los secretos de admin se crean vacíos.** Después de cada `apply` que los cree, hay que cargarles un valor aleatorio, sin que quede escrito en la terminal.

Git Bash:

```bash
aws secretsmanager put-secret-value --secret-id tero/dev/admin-password --secret-string "$(openssl rand -base64 24)"
aws secretsmanager put-secret-value --secret-id tero/dev/admin-jwt-secret --secret-string "$(openssl rand -base64 24)"
```

PowerShell:

```powershell
$bytes = New-Object byte[] 24; [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes); $valor = [Convert]::ToBase64String($bytes)
aws secretsmanager put-secret-value --secret-id tero/dev/admin-password --secret-string $valor
```

(En PowerShell, repetir con un valor nuevo para `tero/dev/admin-jwt-secret`.) Para otro ambiente, cambiar `dev` por `test` o `prod`.

Los valores por defecto están pensados para Academy, donde todo se destruye y se recrea: la base no tiene protección contra borrado ni snapshot final, y los secretos se borran al instante. En prod se endurecen desde `envs/prod.tfvars` (`db_deletion_protection = true`, `db_skip_final_snapshot = false`, `secrets_recovery_window_days = 7`).

Cada ambiente tiene sus valores en `infra/envs/<ambiente>.tfvars`:

| | dev | test | prod |
|--|--|--|--|
| Tasks por servicio | 1 | 1 | 2, repartidas entre las zonas |
| CPU / memoria por task | 256 / 512 MiB | 256 / 512 MiB | 512 / 1024 MiB |
| Retención de logs | 7 días | 14 días | 30 días |
| Protección contra borrado de la base | no | no | sí |
| Snapshot final al destruir | no | no | sí |
| Recuperación de secretos borrados | al instante | al instante | 7 días |

`image_tag`, `admin_ingress_cidr` y `alarm_email` no van en los `.tfvars`: el primero cambia en cada deploy, el segundo es la IP de quien despliega y el tercero es un email personal (el repo es público). Se pasan con `-var`.

Para destruir prod hay que sacar primero la protección de la base: `terraform apply -var-file=envs/prod.tfvars -var db_deletion_protection=false ...` y después el `destroy`. Al destruir prod quedan dos cosas a tener en cuenta:

- **Snapshot final:** RDS guarda un snapshot `tero-prod-postgres-final-<fecha>`, uno por cada vez que se destruye. Ocupa espacio y gasta presupuesto, así que conviene borrar los que ya no sirvan:

  ```bash
  aws rds describe-db-snapshots --snapshot-type manual --query "DBSnapshots[].DBSnapshotIdentifier"
  aws rds delete-db-snapshot --db-snapshot-identifier tero-prod-postgres-final-<fecha>
  ```

- **Secretos de admin:** quedan reservados 7 días (`secrets_recovery_window_days`). Si se vuelve a levantar prod antes, el `apply` falla porque el nombre ya existe. Lo más simple es borrarlos del todo antes del `apply`: Terraform los crea de nuevo y se les carga un valor nuevo (paso de arriba).

  ```bash
  aws secretsmanager delete-secret --secret-id tero/prod/admin-password --force-delete-without-recovery
  aws secretsmanager delete-secret --secret-id tero/prod/admin-jwt-secret --force-delete-without-recovery
  ```

  Para conservar el valor anterior, en cambio, hay que recuperarlos (`aws secretsmanager restore-secret`) e importarlos al state de prod (`terraform import aws_secretsmanager_secret.admin_password <arn>`, lo mismo con `admin_jwt_secret`). Solo recuperarlos no alcanza: el `apply` falla igual porque el secreto existe y no está en el state.

Para no gastar presupuesto, el ambiente se puede destruir cuando no se usa (`terraform destroy -var-file=envs/dev.tfvars -var image_tag=<sha> -var admin_ingress_cidr=<tu-ip>/32 -var alarm_email=<tu-email>`) y volver a crear con el mismo `apply`.

### 5. Inicializar la base (una vez por ambiente)

RDS arranca vacío: solo existe `orders`. El script `init-db.sql` crea `catalogdb`, `cartdb`, los permisos y la tabla `cart_items`. Como RDS está en subnets privadas, se corre con una task one-off de ECS (imagen `postgres:16.13`) dentro de la VPC. Desde la raíz del repo, con las credenciales de la cuenta compartida y después del `apply`:

```bash
./scripts/init-db.sh
```

Imprime los logs y termina con código 0 si salió bien. Es idempotente: se puede repetir sin errores. Hay que hacerlo en cada ambiente nuevo (`dev`, `test`, `prod`), apuntando `terraform` al ambiente con `init -reconfigure` como en el paso 2. Si los servicios `catalog`, `carts` u `orders` fallan al arrancar por falta de tablas o bases, es lo que falta ejecutar.

### 6. Verificar los servicios

En un ambiente nuevo los servicios arrancan antes de que existan las bases y los valores de los secretos, así que los primeros intentos fallan. ECS los reintenta, pero si fallan muchas veces seguidas el circuit breaker corta el despliegue y el servicio queda en `FAILED`. Por eso el orden es `apply`, cargar los secretos (paso 4), `init-db.sh` (paso 5) y después revisar:

```bash
aws ecs describe-services --cluster tero-dev --services ui catalog carts orders checkout admin \
  --query "services[].[serviceName,runningCount,deployments[0].rolloutState]" --output text
```

Los seis tienen que estar en `COMPLETED` con una tarea corriendo. Si alguno quedó en `FAILED`, se relanza con:

```bash
aws ecs update-service --cluster tero-dev --service <servicio> --force-new-deployment
```

La tienda queda en el output `alb_url` y el panel de admin en `alb_admin_url` (usuario `admin`, la contraseña se lee con `aws secretsmanager get-secret-value --secret-id tero/dev/admin-password --query SecretString --output text`).

`carts` abre una sola conexión a la base al arrancar y no la recupera si se corta (reinicio o mantenimiento de RDS). Su `/health` no consulta la base, así que ECS lo sigue viendo sano, pero el carrito responde 500 con `connection already closed` en los logs. Se arregla con el mismo `--force-new-deployment` sobre `carts`.

### 7. Pipeline de infraestructura

`.github/workflows/infra.yml` corre Terraform desde GitHub Actions:

| Evento | Qué hace |
|--|--|
| PR que toca `infra/` | `fmt -check`, `validate`, Checkov y `plan` de dev. El plan queda como comentario en el PR y como artefacto |
| Merge a `develop` | `plan` y `apply` en dev |
| A mano (Actions → Infra → Run workflow) | `plan` y `apply` en el ambiente elegido. En prod pide aprobación |

Como el repo es público, el plan nunca se imprime tal cual: `scripts/terraform-plan.sh` (lo usan `infra.yml`, `cd.yml` y `promocion.yml`) tapa toda IP `/32` antes de mostrarlo en el log, el comentario y el artefacto.

Checkov bloquea: un hallazgo nuevo hace fallar el PR. Se corrige, o se saltea con `#checkov:skip=<regla>:<motivo>` dentro del recurso, así la justificación queda junto al código. Para correrlo local: `docker run --rm -v "$PWD/infra:/infra" bridgecrew/checkov:3.4.6 -d /infra --framework terraform --compact` (la misma versión que usa el pipeline).

El pipeline no cambia la versión de la app: usa el `image_tag` que ya corre en el ambiente (o el SHA del commit, si todavía no hay servicios; en ese caso, antes del apply espera hasta 20 minutos a que el CD suba las imágenes de ese SHA a ECR y, si no aparecen, falla sin crear nada). Necesita los secrets `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` y `AWS_SESSION_TOKEN` (ver abajo, se renuevan con el script), `ADMIN_INGRESS_CIDR` y `ALARM_EMAIL`. Si las credenciales vencieron, el job `terraform` falla al configurar AWS: hay que renovarlas y volver a correrlo.

El deploy de la app lo hace el CD (`.github/workflows/cd.yml`): en cada merge a `develop`, después de subir las imágenes, el job `deploy (dev)` aplica Terraform con `image_tag` igual al SHA corto del commit, espera a que los servicios queden estables y verifica que todos corran ese `APP_VERSION`. Comparte el grupo de concurrencia con el apply de `infra.yml`, así nunca corren dos `terraform apply` a la vez en dev.

- Si dev está apagado (no existe el cluster o el servicio), el deploy se omite con un aviso y las imágenes quedan en ECR. Se levanta dev con `infra.yml` y el próximo merge despliega.
- Si vencieron las credenciales, o falla cualquier otra consulta a AWS, el job falla: hay que renovarlas y volver a correrlo.
- Si dev se acaba de crear de cero, el deploy falla esperando a que los servicios queden estables hasta que se cargan los secretos de admin (paso 4) y se corre `init-db.sh` (paso 5). Después se vuelve a correr el job.
- Rollback: si una task nueva no arranca, el circuit breaker de ECS vuelve solo a la versión anterior y el job falla en la verificación. Para volver a una versión que sí arrancó, se revierte el commit en `develop` (el CD despliega el revert) o se aplica a mano con `-var image_tag=<sha anterior>`, cuya imagen sigue en ECR.

La promoción a test y prod la hace `.github/workflows/promocion.yml`: un push a `release/*` promueve a test y un push a `main` promueve a prod. No reconstruye nada: despliega el SHA original del commit de `develop` (en un merge commit de `release/*` a `main` es el último commit de la rama de release), así dev, test y prod corren la misma imagen.

- Gates: antes de desplegar, el job `gates` verifica que en ese SHA hayan pasado `CI ok` (incluye los tests), `semgrep`, `trivy-fs` y `gitleaks`, que el deploy del ambiente anterior haya pasado con los tests de integración (`deploy (dev)` para test, `deploy (test)` para prod), que `sonarcloud` haya pasado en el PR que introdujo el commit (en el plan gratis de SonarCloud el quality gate solo existe en PRs y en `main`, no en los push a `develop`), y que las 6 imágenes estén en ECR. Si algo falla, no se promueve.
- prod usa `environment: prod`, con aprobación manual (required reviewers).
- El ambiente tiene que estar levantado (con Infra): si no, el job falla en vez de omitirse.
- `release/*` se mergea a `main` con merge commit, sin squash: con squash se pierde el SHA original y no hay imagen para ese commit.
- Un commit directo en `release/*` no tiene imagen (el CD solo construye en `develop` y en tags `v*`) ni los checks de `semgrep`, `trivy-fs` y `gitleaks`, así que el gate lo frena. Los fixes de una release se hacen por `develop` y se corta una release nueva.

### 8. Análisis de calidad (SonarCloud)

`.github/workflows/sonar.yml` analiza el código en SonarCloud (proyecto `nicolasamoroso_Tero`) en cada PR a `develop` y `main` y en cada push a `main`. No corre en los push a `develop` porque en el plan gratis de SonarCloud solo la rama principal tiene quality gate; el gate de `develop` se aplica en el PR, antes de mergear. Necesita el secret `SONAR_TOKEN`, y en SonarCloud el Automatic Analysis tiene que estar desactivado.

La base es la del laboratorio de SonarCloud (T02): `sonarqube-scan-action` y un `sonar-project.properties` en la raíz. Se agregan dos cosas que el laboratorio no tiene:

- **Coverage.** Antes del análisis corre los tests de catalog, orders, cart y checkout y le pasa los reportes a Sonar. Corre siempre los cuatro, no solo los que cambiaron, para que el coverage de los servicios sin cambios no aparezca en 0. ui y admin no tienen tests.
- **Quality gate que bloquea.** Con `sonar.qualitygate.wait=true` el job espera el resultado del quality gate y falla si no pasa. En el laboratorio el gate solo se ve en SonarCloud y el pipeline sigue igual.

Como el workflow instala dependencias para correr los tests, Sonar también lo analiza: `pip` instala solo paquetes binarios (`--only-binary :all:`) y `yarn` no corre los scripts de instalación (`YARN_ENABLE_SCRIPTS=false`). El aviso por instalar dependencias de Python sin lockfile con hashes quedó aceptado en SonarCloud: las versiones directas están fijadas con `==` y Trivy fs escanea las dependencias.

### 9. Alarmas

Terraform crea alarmas de CloudWatch que avisan por email a través de un tópico SNS (`tero-<ambiente>-alarmas`), cuando se disparan y cuando vuelven a OK:

| Alarma | Condición | Runbook |
|--|--|--|
| 5XX (ALB público e interno) | Más de 5 respuestas 5XX en 5 minutos | [disponibilidad](docs/runbooks/disponibilidad.md) |
| Unhealthy (un servicio) | Al menos una task no pasa el health check durante 2 minutos | [disponibilidad](docs/runbooks/disponibilidad.md) |
| p95 (ALB público e interno) | El p95 del tiempo de respuesta supera 1 segundo en 5 minutos | [rendimiento](docs/runbooks/rendimiento.md) |
| CPU (un servicio) | Más de 80% de CPU durante 10 minutos | [recursos](docs/runbooks/recursos.md) |
| Availability (health-checker) | Algún servicio del ALB interno no responde su `/health` en dos chequeos seguidos, o la Lambda deja de correr | [disponibilidad](docs/runbooks/disponibilidad.md) |

El tópico está cifrado con una clave de KMS propia (`alias/tero-<ambiente>-alarmas`, con rotación anual), porque la clave administrada `aws/sns` no deja publicar a CloudWatch. El email sale de `alarm_email` (secret `ALARM_EMAIL` en los pipelines). Después del primer apply, AWS manda un mail para confirmar la suscripción: hasta que no se confirma, no llega ningún aviso.

**Health-checker.** Una Lambda (`tero-<ambiente>-health-checker`, código en `infra/modules/health-checker/lambda/`) corre cada 5 minutos por una regla de EventBridge. Llama al `/health` de catalog, carts, orders y checkout a través del ALB interno y publica la métrica `Tero/Availability`: `Healthy` por servicio (1 o 0) y `Availability`, el porcentaje de servicios sanos, que es la que mira su alarma.

- Corre dentro de la VPC, en las subnets privadas, porque el ALB interno solo se alcanza desde ahí. Tiene su propio security group, que solo sale hacia los puertos del ALB interno.
- Esas subnets no tienen salida a Internet (no hay NAT, ADR 0001), así que la métrica no se publica con la API de CloudWatch: se escribe en el log con el formato EMF (Embedded Metric Format) y CloudWatch la convierte en métrica. Así no hace falta un VPC endpoint, que tiene costo por hora.
- ui y admin no entran: están solo en el ALB público, que desde las subnets privadas no se alcanza. Los cubren las alarmas de unhealthy.
- La lista de servicios no va en variables de entorno: Terraform la mete en el zip como `targets.json`, junto al código. Así la Lambda no guarda configuración que haya que cifrar con una clave propia.

**Estado desde afuera (`GET /status`).** Una HTTP API de API Gateway expone la misma Lambda en el output `health_status_url`. Responde 200 si los 4 servicios están sanos y 503 si alguno no, con el detalle en JSON. No publica métricas, así las consultas no cambian lo que mira la alarma. Tiene throttling en el stage (1 request por segundo en promedio, 2 de golpe): pasado eso responde 429, para que nadie pueda disparar la Lambda sin límite.

```bash
curl -s "$(terraform -chdir=infra output -raw health_status_url)"
```

Para correrla a mano como lo hace EventBridge, publicando las métricas:

```bash
aws lambda invoke --function-name tero-dev-health-checker salida.json && cat salida.json
```

### 10. Dashboard

Terraform crea un dashboard de CloudWatch por ambiente (`tero-<ambiente>`, URL en el output `dashboard_url`). Es lo primero que se abre cuando salta una alarma, y tiene los mismos umbrales dibujados como línea horizontal:

| Fila | Qué muestra | De dónde sale |
|--|--|--|
| Disponibilidad | % de servicios sanos y health check por servicio | Métrica `Tero/Availability` de la Lambda health-checker |
| Servicios | CPU y memoria (%), red y tasks corriendo por servicio | `AWS/ECS` y Container Insights (`ECS/ContainerInsights`) |
| ALBs | Requests, tiempo de respuesta p95 y respuestas 5XX, del ALB público y del interno | `AWS/ApplicationELB` |
| Base de datos | CPU y conexiones abiertas de RDS | `AWS/RDS` |

### Limitaciones de AWS Academy

- Las credenciales duran unas 4 horas y hay que renovarlas desde el lab (`~/.aws/credentials`).
- El pipeline de GitHub Actions usa esas mismas credenciales como secrets del repo (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`), porque Academy no permite OIDC. Se actualizan con el script, que requiere `aws` y `gh` con sesión iniciada:

  ```bash
  ./scripts/renovar-credenciales-aws.sh
  ```

  Con `--dry-run` solo valida las credenciales, sin subir nada. Hay que correrlo únicamente con las credenciales de la cuenta compartida: con las de otra cuenta, el pipeline dejaría de encontrar el bucket del state.
- No se pueden crear roles de IAM: el código usa el `LabRole` que ya existe.
- No se pueden crear namespaces de Cloud Map, así que no sirven Service Connect ni el service discovery de ECS. Los servicios se llaman entre sí por un ALB interno, que es un segundo ALB por ambiente y suma costo por hora mientras el ambiente está levantado. Por eso conviene hacer `terraform destroy` al terminar el día.
- Si el lab se recrea con otra cuenta de AWS, el bucket del state no existe y hay que repetir el paso 1.
- Las credenciales se anulan cuando termina la sesión del lab o alguien hace *End Lab* / *Start Lab* (error `voc-cancel-cred`). Hay que copiarlas de nuevo, y avisar al equipo antes de reiniciar el lab.

---

## Arquitectura de microservicios

```
          ┌──────────────────────────────────────────────────┐
          │               Usuario / Navegador                │
          └────────────────────────┬─────────────────────────┘
                                   │ HTTP
          ┌────────────────────────▼─────────────────────────┐
          │                   UI  :8080                      │
          │            Node.js 22 / Express                  │
          └───────┬──────────┬──────────┬────────────┬───────┘
                  │          │          │            │  HTTP (proxy)
        ┌─────────▼────┐ ┌───▼─────┐ ┌──▼────────┐ ┌▼──────────┐
        │   Catalog    │ │  Cart   │ │ Checkout  │ │  Orders   │
        │    :8080     │ │  :8080  │ │  :8080    │ │  :8080    │
        │  Go / Gin    │ │ Python  │ │ NestJS/TS │ │ Go / Gin  │
        └──────┬───────┘ └────┬────┘ └─────┬─────┘ └─────┬─────┘
               │              │            │  HTTP        │
               │              │            └─────────────►│
               │              │     ┌───────────────┐     │
               │              │     │    Redis 7    │◄────┤
               │              │     └───────────────┘     │
               └──────────────┴───────────────────────────┘
                                          │
        ┌─────────────────────────────────▼──────────────────────┐
        │                      PostgreSQL 16                     │
        │          catalogdb     │    cartdb    │    orders      │
        └────────────────────────────────────────────────────────┘

          ┌──────────────────────────────────────────────────┐
          │                  Admin  :8081                    │
          │            Node.js 22 / Express                  │
          └────────────────────────┬─────────────────────────┘
                                   │ SQL directo
          ┌────────────────────────▼─────────────────────────┐
          │                  PostgreSQL 16                   │
          └──────────────────────────────────────────────────┘
```

### Flujo de comunicación

| Origen     | Destino    | Protocolo | Descripción                              |
|------------|------------|-----------|------------------------------------------|
| UI         | Catalog    | HTTP REST | Listar y consultar productos             |
| UI         | Cart       | HTTP REST | Agregar, quitar y consultar carrito      |
| UI         | Checkout   | HTTP REST | Iniciar y confirmar el proceso de pago   |
| UI         | Orders     | HTTP REST | Consultar historial de órdenes           |
| Checkout   | Orders     | HTTP REST | Crear orden al confirmar checkout        |
| Checkout   | Redis      | TCP       | Persistencia de sesión de checkout       |
| Catalog    | PostgreSQL | TCP       | Base de datos `catalogdb`                |
| Cart       | PostgreSQL | TCP       | Base de datos `cartdb`                   |
| Orders     | PostgreSQL | TCP       | Base de datos `orders`                   |
| Admin      | PostgreSQL | TCP       | Acceso directo a todas las bases         |

---

## Tecnologías por servicio

| Servicio     | Lenguaje       | Framework        | Runtime         | Persistencia      | Puerto externo |
|--------------|----------------|------------------|-----------------|-------------------|----------------|
| **ui**       | TypeScript     | Express          | Node.js 22      | —                 | 8080           |
| **catalog**  | Go 1.24        | Gin + GORM       | Alpine Linux    | PostgreSQL        | —              |
| **cart**     | Python 3.12    | FastAPI          | Python slim     | PostgreSQL        | —              |
| **checkout** | TypeScript     | NestJS           | Node.js 22      | Redis             | —              |
| **orders**   | Go 1.24        | Gin + GORM       | Alpine Linux    | PostgreSQL        | —              |
| **admin**    | TypeScript     | Express          | Node.js 22      | PostgreSQL        | 8081           |
| **db**       | —              | PostgreSQL 16    | —               | —                 | —              |
| **redis**    | —              | Redis 7          | Alpine Linux    | —                 | —              |

### Dependencias clave

| Servicio     | Dependencias destacadas                                               |
|--------------|-----------------------------------------------------------------------|
| **catalog**  | `gin-gonic/gin`, `gorm`, `go-gorm/postgres`, OpenTelemetry           |
| **cart**     | `FastAPI`, `Uvicorn`, `Pydantic`, `psycopg2`, Prometheus client       |
| **checkout** | `NestJS`, `ioredis`, `class-validator`, OpenTelemetry                 |
| **orders**   | `gin-gonic/gin`, `gorm`, `go-gorm/postgres`, Prometheus              |
| **ui**       | `express`, `http-proxy-middleware`                                    |
| **admin**    | `express`, `pg`, `jsonwebtoken`, `cookie-parser`                      |

---

## Variables de entorno

### UI
| Variable                        | Descripción                  | Default               |
|---------------------------------|------------------------------|-----------------------|
| `RETAIL_UI_ENDPOINTS_CATALOG`   | URL del servicio catalog     | `http://catalog:8080` |
| `RETAIL_UI_ENDPOINTS_CARTS`     | URL del servicio cart        | `http://carts:8080`   |
| `RETAIL_UI_ENDPOINTS_CHECKOUT`  | URL del servicio checkout    | `http://checkout:8080`|
| `RETAIL_UI_ENDPOINTS_ORDERS`    | URL del servicio orders      | `http://orders:8080`  |

### Catalog / Orders / Cart
| Variable                               | Descripción           | Default                       |
|----------------------------------------|-----------------------|-------------------------------|
| `RETAIL_CATALOG_PERSISTENCE_PROVIDER`  | Tipo de persistencia  | `postgres`                    |
| `RETAIL_CATALOG_PERSISTENCE_ENDPOINT`  | Host:Puerto de la DB  | `db:5432`                     |
| `DB_PASSWORD`                          | Contraseña PostgreSQL | — (obligatoria, va en `.env`) |

### Checkout
| Variable                                   | Descripción              | Default               |
|--------------------------------------------|--------------------------|------------------------|
| `RETAIL_CHECKOUT_PERSISTENCE_PROVIDER`     | Tipo de persistencia     | `redis`               |
| `RETAIL_CHECKOUT_PERSISTENCE_REDIS_URL`    | URL de Redis             | `redis://redis:6379`  |
| `RETAIL_CHECKOUT_ENDPOINTS_ORDERS`         | URL del servicio orders  | `http://orders:8080`  |

### Admin
| Variable            | Descripción                | Default                       |
|---------------------|----------------------------|-------------------------------|
| `ADMIN_USERNAME`    | Usuario administrador      | — (obligatoria, va en `.env`) |
| `ADMIN_PASSWORD`    | Contraseña administrador   | — (obligatoria, va en `.env`) |
| `ADMIN_JWT_SECRET`  | Secreto para tokens JWT    | — (obligatoria, va en `.env`) |

---

## Estructura del repositorio

```
app/
├── docker-compose.yml
├── init-db.sql
└── src/
    ├── catalog/        # Go - Catálogo de productos
    ├── cart/           # Python - Carrito de compras
    ├── checkout/       # TypeScript/NestJS - Proceso de pago
    ├── orders/         # Go - Gestión de órdenes
    ├── ui/             # TypeScript/Express - Frontend
    └── admin/          # TypeScript/Express - Panel de administración
```
