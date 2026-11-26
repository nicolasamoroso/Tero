#!/usr/bin/env bash
# Corre los tests de integración (tests/postman) contra la tienda de un ambiente.
# Uso: ENVIRONMENT=dev bash scripts/tests-integracion.sh
# La URL sale del output alb_url de Terraform (hace falta el init del ambiente) o de BASE_URL si está definida.
# Deja el reporte JUnit en tests/postman/reportes/.
set -euo pipefail

: "${ENVIRONMENT:?Falta ENVIRONMENT (dev, test o prod)}"

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_URL="${BASE_URL:-$(terraform -chdir="$RAIZ/infra" output -raw alb_url)}"

mkdir -p "$RAIZ/tests/postman/reportes"
echo "Tests de integración contra $ENVIRONMENT: $BASE_URL"

docker run --rm -v "$RAIZ/tests/postman:/etc/newman" postman/newman:6.1.3-alpine \
  run tero.postman_collection.json \
  --environment "environments/${ENVIRONMENT}.postman_environment.json" \
  --env-var "baseUrl=${BASE_URL}" \
  --timeout-request 10000 \
  --reporters cli,junit \
  --reporter-junit-export "reportes/tests-integracion-${ENVIRONMENT}.xml"
