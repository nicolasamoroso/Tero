# ADR 0001: Sin NAT Gateway; tasks de Fargate en subnets públicas

Estado: aceptada

## Contexto
Los servicios de Tero corren en ECS Fargate y necesitan salida a Internet para bajar sus imágenes de ECR y escribir logs en CloudWatch. La forma habitual es poner las tasks en subnets privadas con un NAT Gateway. Un NAT Gateway cuesta alrededor de USD 32 por mes por zona (más el tráfico procesado; verificar el precio vigente en us-east-1), y el presupuesto de la cuenta de AWS Academy es compartido y limitado.

## Decisión
- Las tasks de Fargate van en las **subnets públicas** con IP pública (`assign_public_ip = true` en el servicio de ECS), sin NAT Gateway.
- El security group de los servicios solo acepta tráfico entrante desde el security group del ALB (y entre servicios). Ninguna regla permite entrar desde Internet.
- RDS y Redis van en **subnets privadas** sin ruta a Internet, y sus security groups solo aceptan tráfico desde los servicios.

## Alternativas consideradas
- **NAT Gateway:** el aislamiento es mayor, pero el costo es fijo por hora y se multiplica por ambiente y por zona. Descartada por presupuesto.
- **VPC endpoints (ECR, S3, logs):** permitirían tasks privadas sin NAT, pero cada endpoint de interfaz también tiene costo mensual y hacen falta varios. Descartada por complejidad y costo.

## Consecuencias
- Las tasks tienen una IP pública, pero no son alcanzables desde Internet mientras el security group se mantenga así. La protección depende de ese security group, por eso va documentada y versionada en Terraform.
- La salida a Internet de los servicios queda abierta; no se filtra por destino.
- En un entorno productivo real con más presupuesto se recomienda migrar a subnets privadas con NAT o VPC endpoints. Cambiarlo solo implica mover las tasks a las subnets privadas y agregar el NAT al módulo `network`.
