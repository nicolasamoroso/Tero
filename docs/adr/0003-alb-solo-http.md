# ADR 0003: ALB solo HTTP, con el panel de admin restringido por IP

Estado: aceptada

## Contexto
El ALB expone la UI (puerto 80) y el panel de admin (puerto 8081). HTTPS necesita un certificado de ACM, y ACM solo emite certificados para dominios propios. En AWS Academy no tenemos un dominio, y el nombre DNS que genera el ALB (`*.elb.amazonaws.com`) no admite certificados.

## Decisión
- El ALB tiene listeners **HTTP** en los puertos 80 (UI) y 8081 (admin). No hay listener HTTPS.
- El panel de admin solo es alcanzable desde el CIDR `admin_ingress_cidr`, mediante una regla en el security group del ALB. Esa restricción es la mitigación principal.

## Alternativas consideradas
- **HTTPS con certificado de ACM:** requiere un dominio propio y validación DNS. Descartada por no disponer de dominio en Academy.
- **Certificado autofirmado importado a ACM:** el navegador lo rechaza y no aporta una garantía real. Descartada.
- **Túnel o VPN hacia el panel:** más seguro, pero agrega infraestructura y costo desproporcionados para este alcance.

## Consecuencias
- El login y el token (JWT) del admin viajan sin cifrar entre el navegador y el ALB. Solo se mitiga limitando quién puede conectarse, no protegiendo el contenido del tráfico.
- La UI pública también viaja sin cifrar.
- En un entorno productivo real hay que registrar un dominio, emitir un certificado en ACM, agregar un listener 443 y redirigir el 80 al 443. En Terraform el cambio queda dentro del módulo `alb`.
