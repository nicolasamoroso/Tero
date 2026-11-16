#!/usr/bin/env bash
# Construye las imágenes de los 6 servicios y las sube a ECR (tero/<servicio>:<tag>).
# Uso: ./scripts/subir-imagenes.sh [--tag TAG] [--region REGION]
# Requiere aws v2 y docker. Por defecto el tag es el SHA corto del commit actual.

set -euo pipefail

TAG=""
REGION="us-east-1"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag) TAG="${2:?falta el valor de --tag}"; shift 2 ;;
    --region) REGION="${2:?falta el valor de --region}"; shift 2 ;;
    -h|--help) sed -n '2,4p' "$0"; exit 0 ;;
    *) echo "Argumento desconocido: $1" >&2; exit 1 ;;
  esac
done

for cmd in aws docker git; do
  command -v "$cmd" >/dev/null || { echo "Falta el comando: $cmd" >&2; exit 1; }
done

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TAG="${TAG:-$(git -C "$ROOT" rev-parse --short HEAD)}"

if ! ACCOUNT="$(aws sts get-caller-identity --query Account --output text 2>/dev/null)"; then
  echo "Credenciales de AWS inválidas o vencidas. Renovarlas en el lab de Academy." >&2
  exit 1
fi

REGISTRY="$ACCOUNT.dkr.ecr.$REGION.amazonaws.com"
SERVICES=(ui catalog cart orders checkout admin)

aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REGISTRY"

for svc in "${SERVICES[@]}"; do
  if aws ecr describe-images --region "$REGION" --repository-name "tero/$svc" --image-ids imageTag="$TAG" >/dev/null 2>&1; then
    echo "tero/$svc:$TAG ya existe en ECR (los tags son inmutables), se omite."
    continue
  fi
  echo "Construyendo tero/$svc:$TAG"
  docker build --platform linux/amd64 -t "$REGISTRY/tero/$svc:$TAG" "$ROOT/src/$svc"
  docker push "$REGISTRY/tero/$svc:$TAG"
done

echo "Listo. Para Terraform usar -var image_tag=$TAG"
