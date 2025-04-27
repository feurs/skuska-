#!/usr/bin/env bash
set -euo pipefail
RG="cloudexam-rg"
echo "🗑  Ruším Resource Group $RG..."
az group delete -g "$RG" --yes --no-wait

