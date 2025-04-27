#!/usr/bin/env bash
set -euo pipefail

### KONFIG ##################################################
RG="cloudexam-rg"
LOC="westeurope"
APP_NAME="cloudexam$(date +%s)"              # Static Web App už existuje – meno frontend-u
ACR="cr${APP_NAME}"
POSTGRES="pg${APP_NAME}"
PG_ADMIN="pgadmin"                           # admin user
PG_PASS=$(openssl rand -base64 16)
CA_ENV="cae-${APP_NAME}"
BACKEND_CA="backend"
IMG_TAG="v1"
GITHUB_REPO="feurs/skuska-"                  # tvoj GitHub repo
SWA_NAME="skuska"                            # už vytvorená Static Web App
#############################################################

echo "1️⃣  Resource Group"
az group create -n "$RG" -l "$LOC"

echo "2️⃣  Azure Container Registry"
az acr create -n "$ACR" -g "$RG" --sku Basic
az acr login  -n "$ACR"

echo "3️⃣  Build & push backend image"
az acr build -t backend:$IMG_TAG -r "$ACR" -f backend/Dockerfile.backend backend/

echo "4️⃣  PostgreSQL Flexible Server"
az postgres flexible-server create \
     --name "$POSTGRES" \
     --resource-group "$RG" \
     --location "$LOC" \
     --admin-user "$PG_ADMIN" \
     --admin-password "$PG_PASS" \
     --sku-name Standard_B1ms \
     --storage-size 5 \
     --public-access 0.0.0.0-255.255.255.255

PG_HOST="$(az postgres flexible-server show -g $RG -n $POSTGRES --query fullyQualifiedDomainName -o tsv)"
DB_URL="postgresql://${PG_ADMIN}:${PG_PASS}@${PG_HOST}:5432/postgres"

echo "5️⃣  Container Apps Environment"
az containerapp env create -n "$CA_ENV" -g "$RG" -l "$LOC"

echo "6️⃣  Backend Container App"
az containerapp create \
  --name "$BACKEND_CA" \
  --resource-group "$RG" \
  --environment "$CA_ENV" \
  --ingress external --target-port 8000 \
  --registry-server "$ACR.azurecr.io" \
  --image "$ACR.azurecr.io/backend:$IMG_TAG" \
  --env-vars DATABASE_URL="$DB_URL"

BACKEND_URL=$(az containerapp show -n $BACKEND_CA -g $RG --query properties.latestReadyRevisionfqdn -o tsv)
echo "   Backend dostupný na: https://$BACKEND_URL"

echo "7️⃣  Napojíme URL backendu do Static Web App"
az staticwebapp appsettings set \
   --name "$SWA_NAME" \
   --setting-names VITE_BACKEND_URL="https://${BACKEND_URL}"

echo "✅  Hotovo.  Front-end URL:"
az staticwebapp show -n "$SWA_NAME" --query defaultHostname -o tsv

