#!/bin/bash
# FreshBox SpA - Deploy contenedores en EC2 APP (EP1)
# Uso: ./deploy-containers.sh <IP_PRIVADA_MYSQL>

set -e

REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
# Si se entrega una IP como parametro, utilizarla.
# Si no, leer automaticamente la IP guardada por Terraform.
if [ -n "$1" ]; then
    DB_HOST="$1"
elif [ -f "/home/ec2-user/mysql-private-ip.txt" ]; then
    DB_HOST=$(cat /home/ec2-user/mysql-private-ip.txt)
else
    echo "ERROR: No se pudo determinar la IP privada de MySQL."
    echo "Uso alternativo: ./deploy-containers.sh <IP_PRIVADA_MYSQL>"
    exit 1
fi

echo "=== FreshBox Deploy ==="
echo "Region: $REGION"
echo "MySQL: $DB_HOST"

# Login en ECR
aws ecr get-login-password --region $REGION | \
docker login --username AWS --password-stdin \
$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

# Descargar imagenes
docker pull $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/freshbox-frontend:latest
docker pull $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/freshbox-get-products:latest
docker pull $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/freshbox-create-product:latest
docker pull $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/freshbox-update-product:latest
docker pull $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/freshbox-delete-product:latest

# Eliminar despliegue anterior si existe
docker rm -f freshbox-frontend 2>/dev/null || true
docker rm -f freshbox-get-products 2>/dev/null || true
docker rm -f freshbox-create-product 2>/dev/null || true
docker rm -f freshbox-update-product 2>/dev/null || true
docker rm -f freshbox-delete-product 2>/dev/null || true

# Crear red Docker si no existe
docker network inspect freshbox-net >/dev/null 2>&1 || \
docker network create freshbox-net

# GET
docker run -d \
  --name freshbox-get-products \
  --network freshbox-net \
  --network-alias get-products \
  -p 3001:3001 \
  -e DB_HOST="$DB_HOST" \
  -e DB_USER=alumno \
  -e DB_PASS=$DB_PASSWORD \
  -e DB_NAME=freshbox \
  -e DB_PORT=3306 \
  -e PORT=3001 \
  $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/freshbox-get-products:latest

# CREATE
docker run -d \
  --name freshbox-create-product \
  --network freshbox-net \
  --network-alias create-product \
  -p 3002:3002 \
  -e DB_HOST="$DB_HOST" \
  -e DB_USER=alumno \
  -e DB_PASS=$DB_PASSWORD \
  -e DB_NAME=freshbox \
  -e DB_PORT=3306 \
  -e PORT=3002 \
  $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/freshbox-create-product:latest

# UPDATE
docker run -d \
  --name freshbox-update-product \
  --network freshbox-net \
  --network-alias update-product \
  -p 3003:3003 \
  -e DB_HOST="$DB_HOST" \
  -e DB_USER=alumno \
  -e DB_PASS=$DB_PASSWORD \
  -e DB_NAME=freshbox \
  -e DB_PORT=3306 \
  -e PORT=3003 \
  $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/freshbox-update-product:latest

# DELETE
docker run -d \
  --name freshbox-delete-product \
  --network freshbox-net \
  --network-alias delete-product \
  -p 3004:3004 \
  -e DB_HOST="$DB_HOST" \
  -e DB_USER=alumno \
  -e DB_PASS=$DB_PASSWORD \
  -e DB_NAME=freshbox \
  -e DB_PORT=3306 \
  -e PORT=3004 \
  $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/freshbox-delete-product:latest

# FRONTEND
docker run -d \
  --name freshbox-frontend \
  --network freshbox-net \
  -p 80:80 \
  $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/freshbox-frontend:latest

echo ""
echo "=== Contenedores ejecutandose ==="
docker ps

echo ""
echo "=== Deploy FreshBox completado ==="


