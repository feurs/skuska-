#!/usr/bin/env bash
set -euo pipefail

RG="cloudexam-rg"
LOC="westeurope"
ACR="crcloudexam1745721511"

PG_REGION="northeurope"
POSTGRES="pg-${RG}-$(date +%s)"
PG_ADMIN="pgadmin"
PG_PASS=$(openssl rand -base64 16)

ENV_CA="cae-${RG}"
SWA_NAME="skuska"

echo "🔑  Register providers"
for p in Microsoft.ContainerRegistry Microsoft.DBforPostgreSQL \
         Microsoft.App Microsoft.OperationalInsights; do
  az provider register -n "$p" --wait
done

az group create -n "$RG" -l "$LOC"

# ACR (admin zapnutý kvôli CI)
az acr create -n "$ACR" -g "$RG" --sku Basic -l "$LOC" --admin-enabled true

# PostgreSQL (ak ešte neexistuje)
if ! az postgres flexible-server show -g "$RG" -n "$POSTGRES" &>/dev/null; then
  az postgres flexible-server create \
     --name "$POSTGRES" --resource-group "$RG" --location "$PG_REGION" \
     --admin-user "$PG_ADMIN" --admin-password "$PG_PASS" \
     --tier Burstable --sku-name Standard_B1ms --version 16 --storage-size 32 \
     --create-default-database Disabled --public-access 0.0.0.0-255.255.255.255
fi

# Container Apps Environment
az containerapp env create -n "$ENV_CA" -g "$RG" -l "$LOC"

# Static Web Apps už vytvorená ručne/CLI pri prvom nasadení frontendu
echo "🆗  Infra ready.  Backend bude nasadzovať GitHub Action."
