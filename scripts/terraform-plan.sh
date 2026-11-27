#!/usr/bin/env bash
# Corre terraform plan para los pipelines sin que ninguna IP quede publicada (el repo es público).
# Uso (desde infra/, con ENVIRONMENT y los TF_VAR_* definidos):
#   bash ../scripts/terraform-plan.sh
# Deja tfplan para el apply y plan.txt (el plan legible, con las IP tapadas) para el log, el comentario
# del PR y el artefacto.
#
# Por qué no alcanza con que GitHub tape los secrets: si alguien aplicó a mano desde otra IP, el plan
# muestra el cambio de esa IP a la del secret, y esa no es un secret. Por eso el plan no se imprime
# tal cual y se tapa toda IP /32 (las del admin). Los CIDR de la VPC y 0.0.0.0/0 no se tocan.
set -euo pipefail

: "${ENVIRONMENT:?Falta ENVIRONMENT (dev, test o prod)}"

# La salida del plan va a /dev/null; si falla, el error se ve igual porque sale por stderr
terraform plan -input=false -lock-timeout=5m -var-file="envs/${ENVIRONMENT}.tfvars" -out=tfplan > /dev/null
terraform show -no-color tfplan > plan-completo.txt

# [.] en vez de . para que sed busque el punto literal y no "cualquier carácter"
IP_32='[0-9]{1,3}([.][0-9]{1,3}){3}/32'
sed -E "s#${IP_32}#***/32#g" plan-completo.txt > plan.txt
rm plan-completo.txt

if grep -qE "$IP_32" plan.txt; then
  echo "::error::Quedó una IP en el plan, no se publica"
  rm plan.txt
  exit 1
fi

cat plan.txt
