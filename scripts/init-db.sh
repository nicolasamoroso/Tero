#!/usr/bin/env bash
# Inicializa la base de un ambiente: corre init-db.sql en una task de ECS dentro de la VPC.
# Uso (desde cualquier carpeta, con las credenciales de la cuenta compartida):
#   ./scripts/init-db.sh
# Se puede repetir sin problema: el script SQL es idempotente.
set -euo pipefail

export MSYS_NO_PATHCONV=1          # Git Bash cambia los argumentos que empiezan con /
export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-us-east-1}"

cd "$(dirname "$0")/../infra"

CLUSTER=$(terraform output -raw db_init_cluster)
TASKDEF=$(terraform output -raw db_init_task_definition)
SUBNETS=$(terraform output -raw db_init_subnets)
SG=$(terraform output -raw db_init_security_group)
LOGGROUP=$(terraform output -raw db_init_log_group)

TASK_ARN=$(aws ecs run-task \
  --cluster "$CLUSTER" \
  --launch-type FARGATE \
  --task-definition "$TASKDEF" \
  --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],securityGroups=[$SG],assignPublicIp=ENABLED}" \
  --query 'tasks[0].taskArn' --output text)
TASK_ID="${TASK_ARN##*/}"
echo "Task iniciada: $TASK_ARN"

aws ecs wait tasks-stopped --cluster "$CLUSTER" --tasks "$TASK_ARN"

CODE=$(aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$TASK_ARN" \
  --query 'tasks[0].containers[0].exitCode' --output text)
REASON=$(aws ecs describe-tasks --cluster "$CLUSTER" --tasks "$TASK_ARN" \
  --query 'tasks[0].[stoppedReason,containers[0].reason]' --output text)

# Solo los logs de esta task (el stream se llama db-init/db-init/<id de la task>)
echo "---- logs ----"
aws logs tail "$LOGGROUP" --since 15m --log-stream-name-prefix "db-init/db-init/$TASK_ID" || true

if [ "$CODE" != "0" ]; then
  echo "---- la task falló (exitCode: $CODE) ----" >&2
  echo "Motivo: $REASON" >&2
  exit 1
fi
echo "---- código de salida: 0 ----"
