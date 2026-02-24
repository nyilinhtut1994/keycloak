# Keycloak Service Deployment

Automated Keycloak deployment to Azure Container Apps using GitHub Actions.

## Prerequisites

1. **Azure Resources** (create these first):
   - Azure Container Registry (ACR)
   - Azure Container Apps Environment
   - Azure PostgreSQL Flexible Server
   - Azure Container App (initial creation)

2. **GitHub Repository Secrets** (Settings → Secrets and variables → Actions):
   - `AZURE_CREDENTIALS` - Azure service principal credentials
   - `DB_HOST` - PostgreSQL server hostname (e.g., `myserver.postgres.database.azure.com`)
   - `DB_NAME` - Database name (e.g., `keycloak`)
   - `DB_USERNAME` - Database username
   - `DB_PASSWORD` - Database password
   - `KEYCLOAK_HOSTNAME` - Your Keycloak public URL (e.g., `keycloak.yourdomain.com`)
   - `KEYCLOAK_ADMIN` - Keycloak admin username
   - `KEYCLOAK_ADMIN_PASSWORD` - Keycloak admin password

## Setup Steps

### 1. Create Azure Resources

```bash
# Variables
RG="keycloak-rg"
LOCATION="eastus"
ACR_NAME="keycloakacr"
ENV_NAME="keycloak-env"
APP_NAME="keycloak-app"
DB_SERVER="keycloak-db"
DB_NAME="keycloak"
DB_USER="keycloakadmin"
DB_PASSWORD="<your-secure-password>"

# Create resource group
az group create --name $RG --location $LOCATION

# Create Azure Container Registry
az acr create --resource-group $RG --name $ACR_NAME --sku Basic --admin-enabled true

# Create PostgreSQL Flexible Server
az postgres flexible-server create \
  --resource-group $RG \
  --name $DB_SERVER \
  --location $LOCATION \
  --admin-user $DB_USER \
  --admin-password $DB_PASSWORD \
  --sku-name Standard_B1ms \
  --tier Burstable \
  --version 15 \
  --storage-size 32

# Create database
az postgres flexible-server db create \
  --resource-group $RG \
  --server-name $DB_SERVER \
  --database-name $DB_NAME

# Create Container Apps Environment
az containerapp env create \
  --name $ENV_NAME \
  --resource-group $RG \
  --location $LOCATION

# Create Container App (initial)
az containerapp create \
  --name $APP_NAME \
  --resource-group $RG \
  --environment $ENV_NAME \
  --image quay.io/keycloak/keycloak:latest \
  --target-port 8080 \
  --ingress external \
  --registry-server $ACR_NAME.azurecr.io \
  --cpu 1 \
  --memory 2Gi \
  --min-replicas 1 \
  --max-replicas 3

# Allow Container App to access PostgreSQL
az postgres flexible-server firewall-rule create \
  --resource-group $RG \
  --name $DB_SERVER \
  --rule-name allow-azure-services \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0
```

### 2. Create Azure Service Principal

```bash
az ad sp create-for-rbac \
  --name "github-keycloak-deploy" \
  --role contributor \
  --scopes /subscriptions/<subscription-id>/resourceGroups/$RG \
  --sdk-auth
```

Copy the JSON output and save it as `AZURE_CREDENTIALS` secret in GitHub.

### 3. Update Workflow Configuration

Edit `.github/workflows/deploy.yml` and replace:
- `<your-acr-name>` with your ACR name
- `<your-resource-group>` with your resource group name

### 4. Deploy

Push to `main` branch or trigger workflow manually from GitHub Actions tab.

## Access Keycloak

After deployment, access Keycloak at: `https://<your-container-app-url>`

Admin console: `https://<your-container-app-url>/admin`

## Database Connection

Keycloak connects to PostgreSQL using environment variables configured in the workflow.
