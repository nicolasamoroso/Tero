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

# Imagen fijada por digest (6.1.3-alpine): un tag se puede volver a publicar, el digest no
docker run --rm -v "$RAIZ/tests/postman:/etc/newman" \
  postman/newman:6.1.3-alpine@sha256:d9b5e780ead0026bbb37f3759cd7b10fc8a88cd4030c8266a7c5e343d75a5198 \
  run tero.postman_collection.json \
  --environment "environments/${ENVIRONMENT}.postman_environment.json" \
  --env-var "baseUrl=${BASE_URL}" \
  --timeout-request 10000 \
  --reporters cli,junit \
  --reporter-junit-export "reportes/tests-integracion-${ENVIRONMENT}.xml"
