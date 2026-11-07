#!/usr/bin/env bash
# Sube las credenciales de AWS Academy (duran ~4 h, sin OIDC) como secrets del repo.
# Uso: ./scripts/renovar-credenciales-aws.sh [--repo owner/nombre] [--profile perfil] [--dry-run]
# Requiere aws v2 y gh con sesión iniciada.

set -euo pipefail

REPO=""
PROFILE="default"
DRY_RUN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO="${2:?falta el valor de --repo}"; shift 2 ;;
    --profile) PROFILE="${2:?falta el valor de --profile}"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) sed -n '2,4p' "$0"; exit 0 ;;
    *) echo "Argumento desconocido: $1" >&2; exit 1 ;;
  esac
done

for cmd in aws gh; do
  command -v "$cmd" >/dev/null || { echo "Falta el comando: $cmd" >&2; exit 1; }
done

if [[ -z "$REPO" ]]; then
  REPO="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
fi

get() { aws configure get "$1" --profile "$PROFILE" 2>/dev/null || true; }

ACCESS_KEY_ID="$(get aws_access_key_id)"
SECRET_ACCESS_KEY="$(get aws_secret_access_key)"
SESSION_TOKEN="$(get aws_session_token)"

for pair in "aws_access_key_id:$ACCESS_KEY_ID" "aws_secret_access_key:$SECRET_ACCESS_KEY" "aws_session_token:$SESSION_TOKEN"; do
  if [[ -z "${pair#*:}" ]]; then
    echo "No se encontró ${pair%%:*} en el perfil '$PROFILE' de ~/.aws/credentials" >&2
    exit 1
  fi
done

# No se suben credenciales vencidas: se comprueba antes de tocar GitHub
if ! ACCOUNT="$(AWS_PROFILE="$PROFILE" aws sts get-caller-identity --query Account --output text 2>/dev/null)"; then
  echo "Las credenciales del perfil '$PROFILE' no son válidas o están vencidas. Renovarlas en el lab de Academy." >&2
  exit 1
fi

echo "Credenciales válidas (cuenta $ACCOUNT). Repositorio: $REPO"

if [[ "$DRY_RUN" == true ]]; then
  echo "[dry-run] Se actualizarían: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_SESSION_TOKEN"
  exit 0
fi

# El valor entra por stdin: no queda en la línea de comandos ni en el historial
set_secret() {
  printf '%s' "$2" | gh secret set "$1" --repo "$REPO"
}

set_secret AWS_ACCESS_KEY_ID "$ACCESS_KEY_ID"
set_secret AWS_SECRET_ACCESS_KEY "$SECRET_ACCESS_KEY"
set_secret AWS_SESSION_TOKEN "$SESSION_TOKEN"

echo "Listo: secrets actualizados en $REPO. Vencen en unas 4 horas."
