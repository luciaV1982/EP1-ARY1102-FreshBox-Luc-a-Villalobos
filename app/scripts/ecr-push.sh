#!/bin/bash
# FreshBox SpA - Build y Push de imagenes ARM64 a ECR (EP1)
# Puede ejecutarse desde cualquier carpeta del proyecto

set -e

# Detectar automaticamente la carpeta app/
# SCRIPT_DIR = carpeta donde esta este script (app/scripts)
# APP_DIR    = carpeta app/
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

echo "=== FreshBox Build & Push ==="
echo "Account: $ACCOUNT_ID"
echo "Region: $REGION"
echo "Carpeta APP: $APP_DIR"

# Login en ECR
aws ecr get-login-password --region "$REGION" | \
docker login --username AWS --password-stdin "$ECR"

# Crear/usar builder Buildx
if ! docker buildx inspect freshbox-builder >/dev/null 2>&1; then
    docker buildx create \
      --name freshbox-builder \
      --driver docker-container \
      --use
else
    docker buildx use freshbox-builder
fi

docker buildx inspect --bootstrap

echo "=== Construyendo y subiendo FRONTEND ==="
docker buildx build \
  --platform linux/arm64 \
  -t "$ECR/freshbox-frontend:latest" \
  --push \
  "$APP_DIR/microservicioFrontend"

echo "=== Construyendo y subiendo GET ==="
docker buildx build \
  --platform linux/arm64 \
  -t "$ECR/freshbox-get-products:latest" \
  --push \
  "$APP_DIR/microserviciosBackend/get-products"

echo "=== Construyendo y subiendo CREATE ==="
docker buildx build \
  --platform linux/arm64 \
  -t "$ECR/freshbox-create-product:latest" \
  --push \
  "$APP_DIR/microserviciosBackend/create-product"

echo "=== Construyendo y subiendo UPDATE ==="
docker buildx build \
  --platform linux/arm64 \
  -t "$ECR/freshbox-update-product:latest" \
  --push \
  "$APP_DIR/microserviciosBackend/update-product"

echo "=== Construyendo y subiendo DELETE ==="
docker buildx build \
  --platform linux/arm64 \
  -t "$ECR/freshbox-delete-product:latest" \
  --push \
  "$APP_DIR/microserviciosBackend/delete-product"

echo ""
echo "=== Las 5 imagenes FreshBox fueron subidas a ECR ==="