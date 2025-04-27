
#!/usr/bin/env bash
# Global variables for deployment. Edit values as needed.

# Azure
export AZ_SUBSCRIPTION="c40cb43d-b4a2-4396-ac51-13f0bc33d204"
export RG="cloudexam-rg"
export LOCATION="westeurope"

# Registry
export ACR="examacrdenis$RANDOM"
export TAG="latest"
export IMG_FRONT="front"
export IMG_BACK="back"

# Container Apps
export CA_ENV="cae-cloudexam-rg"
export CA_FRONT="exam-front"
export CA_BACK="exam-back"

# Storage
export STG="examstg$RANDOM"
export FILE_SHARE="staticshare"

# Database
export PG_USER="postgres"
export PG_DB="mydb"
export PG_PW="$(openssl rand -hex 16)"

# helper
_blue(){ echo -e "\033[1;34m$*\033[0m"; }
