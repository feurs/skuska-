
# Exam Deployment Template

This repository contains a minimal, **clean-ASCII** starting point that fulfils the
faculty exam requirements:

* Front‑end (React build in Nginx)  
* Back‑end (FastAPI)  
* PostgreSQL (local via docker‑compose, optional in Azure)  
* Deployment scripts for Azure Container Apps  
* Scripts are idempotent and portal‑free.  

## Quick start

```bash
# Edit vars.sh with your Subscription ID and custom names
./prepare-app.sh       # deploy to Azure
./remove-app.sh        # tear down everything
```

All code and scripts are plain ASCII – no hidden characters that might break Azure CLI.
