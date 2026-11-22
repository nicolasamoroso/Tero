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
terraform plan -var-file=envs/dev.tfvars -var image_tag=<sha> -var admin_ingress_cidr=<tu-ip>/32
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
terraform apply -var-file=envs/dev.tfvars -var image_tag=<sha> -var admin_ingress_cidr=<tu-ip>/32
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

`image_tag` y `admin_ingress_cidr` no van en los `.tfvars`: el primero cambia en cada deploy y el segundo es la IP de quien despliega. Se pasan con `-var`.

Para destruir prod hay que sacar primero la protección de la base: `terraform apply -var-file=envs/prod.tfvars -var db_deletion_protection=false ...` y después el `destroy`. Al destruir prod quedan dos cosas a tener en cuenta:

- **Snapshot final:** RDS guarda un snapshot `tero-prod-postgres-final-<fecha>`, uno por cada vez que se destruye. Ocupa espacio y gasta presupuesto, así que conviene borrar los que ya no sirvan:

  ```bash
  aws rds describe-db-snapshots --snapshot-type manual --query "DBSnapshots[].DBSnapshotIdentifier"
  aws rds delete-db-snapshot --db-snapshot-identifier tero-prod-postgres-final-<fecha>
  ```

- **Secretos de admin:** quedan reservados 7 días (`secrets_recovery_window_days`). Si se vuelve a levantar prod antes, el `apply` falla porque el nombre ya existe. Hay dos salidas: recuperarlos (Terraform los vuelve a tomar, con su valor) o borrarlos del todo (hay que volver a cargarles un valor):

  ```bash
  aws secretsmanager restore-secret --secret-id tero/prod/admin-password
  aws secretsmanager delete-secret --secret-id tero/prod/admin-password --force-delete-without-recovery
  ```

  Lo mismo para `tero/prod/admin-jwt-secret`.

Para no gastar presupuesto, el ambiente se puede destruir cuando no se usa (`terraform destroy -var-file=envs/dev.tfvars -var image_tag=<sha> -var admin_ingress_cidr=<tu-ip>/32`) y volver a crear con el mismo `apply`.

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

El pipeline no cambia la versión de la app: usa el `image_tag` que ya corre en el ambiente (o el SHA del commit, si todavía no hay servicios; en ese caso, antes del apply espera hasta 20 minutos a que el CD suba las imágenes de ese SHA a ECR y, si no aparecen, falla sin crear nada). Necesita los secrets `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` y `AWS_SESSION_TOKEN` (ver abajo, se renuevan con el script) y `ADMIN_INGRESS_CIDR`. Si las credenciales vencieron, el job `terraform` falla al configurar AWS: hay que renovarlas y volver a correrlo.

### 8. Análisis de calidad (SonarCloud)

`.github/workflows/sonar.yml` analiza el código en SonarCloud (proyecto `nicolasamoroso_Tero`) en cada PR y push a `develop` y `main`. Necesita el secret `SONAR_TOKEN`, y en SonarCloud el Automatic Analysis tiene que estar desactivado.

La base es la del laboratorio de SonarCloud (T02): `sonarqube-scan-action` y un `sonar-project.properties` en la raíz. Se agregan dos cosas que el laboratorio no tiene:

- **Coverage.** Antes del análisis corre los tests de catalog, orders, cart y checkout y le pasa los reportes a Sonar. Corre siempre los cuatro, no solo los que cambiaron, para que el coverage de los servicios sin cambios no aparezca en 0. ui y admin no tienen tests.
- **Quality gate que bloquea.** Con `sonar.qualitygate.wait=true` el job espera el resultado del quality gate y falla si no pasa. En el laboratorio el gate solo se ve en SonarCloud y el pipeline sigue igual.

Como el workflow instala dependencias para correr los tests, Sonar también lo analiza: `pip` instala solo paquetes binarios (`--only-binary :all:`) y `yarn` no corre los scripts de instalación (`YARN_ENABLE_SCRIPTS=false`). El aviso por instalar dependencias de Python sin lockfile con hashes quedó aceptado en SonarCloud: las versiones directas están fijadas con `==` y Trivy fs escanea las dependencias.

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
