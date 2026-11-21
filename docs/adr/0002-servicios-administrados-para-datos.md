# ADR 0002: Servicios administrados para los datos (RDS y ElastiCache)

Estado: aceptada

## Contexto
Tero necesita PostgreSQL (bases `orders`, `catalogdb` y `cartdb`) y Redis. Hay que decidir si los corremos como contenedores propios en ECS o como servicios administrados de AWS.

## Decisión
- Usamos Amazon RDS for PostgreSQL 16 y Amazon ElastiCache for Redis 7.1, creados con los módulos `database` y `cache` de Terraform.
- La contraseña del usuario maestro la genera y guarda RDS (`manage_master_user_password`).
- RDS exige SSL por defecto en PostgreSQL 16, pero `catalog` y `orders` traen `sslmode=disable` en su código, así que el parameter group pone `rds.force_ssl = 0`. La task de `db-init` sí usa `PGSSLMODE=require`.

## Alternativas consideradas
- **Postgres y Redis como contenedores en ECS Fargate:** evita el costo por hora de RDS, pero Fargate no ofrece almacenamiento persistente simple para una base; habría que sumar EFS o aceptar perder los datos al reiniciar la tarea, y los backups y las actualizaciones quedarían a nuestro cargo.
- **Amazon Aurora:** más escalado y alta disponibilidad, pero con más costo y complejidad de los que necesita este proyecto.

## Consecuencias
- Los backups y los parches de la base los gestiona AWS.
- Los recursos cobran por hora mientras existan: hay que destruir el entorno cuando no se usa (`terraform destroy`).
- Crear RDS tarda varios minutos (10 a 15 aproximadamente), lo que alarga cada `apply` desde cero.
- El tráfico a la base no va cifrado, pero no sale de la VPC: RDS está en subnets privadas y solo acepta conexiones de los servicios.
- En AWS Academy dependemos de los permisos del rol del laboratorio y de sus credenciales temporales.
