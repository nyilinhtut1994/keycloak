# Azure Portal Setup Guide for Keycloak Deployment

## Step 1: Use Existing Resource Group

You'll use your existing resource group: `cmhl-preprod-rg`

## Step 2: Create Azure Container Registry (ACR)

1. Search for "Container registries" → Click "Create"
2. Fill in:
   - **Resource group**: `cmhl-preprod-rg`
   - **Registry name**: `keycloakacr` (must be globally unique, use your own name)
   - **Location**: Same as resource group
   - **SKU**: `Basic`
3. Click "Review + create" → "Create"
4. After creation, go to the ACR resource:
   - Go to "Settings" → "Access keys"
   - Enable "Admin user"
   - Note down the registry name (you'll need it for GitHub workflow)

## Step 3: Create PostgreSQL Flexible Server

1. Search for "Azure Database for PostgreSQL flexible servers" → Click "Create"
2. Fill in:
   - **Resource group**: `cmhl-preprod-rg`
   - **Server name**: `keycloak-db` (must be globally unique)
   - **Region**: Same as resource group
   - **PostgreSQL version**: `15`
   - **Workload type**: `Development`
   - **Compute + storage**: `Burstable, B1ms` (1 vCore, 2 GiB RAM)
   - **Admin username**: `keycloakadmin`
   - **Password**: Create a strong password (save it securely)
3. Click "Next: Networking"
   - **Connectivity method**: `Public access`
   - Check "Allow public access from any Azure service within Azure to this server"
4. Click "Review + create" → "Create" (takes 5-10 minutes)
5. After creation, go to the PostgreSQL resource:
   - Go to "Settings" → "Databases" → Click "Add"
   - **Database name**: `keycloak`
   - Click "Save"
   - Note down:
     - Server name (e.g., `keycloak-db.postgres.database.azure.com`)
     - Database name: `keycloak`
     - Admin username: `keycloakadmin`
     - Password: (the one you created)

## Step 4: Create Container Apps Environment

1. Search for "Container Apps" → Click "Create"
2. On the "Basics" tab:
   - **Resource group**: `cmhl-preprod-rg`
   - **Container app name**: `keycloak-app`
   - **Region**: Same as resource group
3. Click "Create new" under "Container Apps Environment":
   - **Environment name**: `keycloak-env`
   - Click "Create"
4. Click "Next: Container"
5. On the "Container" tab:
   - Uncheck "Use quickstart image"
   - **Name**: `keycloak`
   - **Image source**: `Docker Hub or other registries`
   - **Image and tag**: `quay.io/keycloak/keycloak:latest`
   - **CPU and Memory**: `1 CPU cores, 2 Gi memory`
6. Click "Next: Ingress"
7. On the "Ingress" tab:
   - Check "Enabled"
   - **Ingress traffic**: `Accepting traffic from anywhere`
   - **Ingress type**: `HTTP`
   - **Target port**: `8080`
8. Click "Review + create" → "Create" (takes 3-5 minutes)
9. After creation, note down:
   - Container App name: `keycloak-app`
   - Application URL (found in "Overview" page)

## Step 5: Create Service Principal for GitHub Actions

1. Open Azure Cloud Shell (click the shell icon in top right of portal)
2. Run this command (replace `<subscription-id>` with your subscription ID):
```bash
az ad sp create-for-rbac \
  --name "github-keycloak-deploy" \
  --role contributor \
  --scopes /subscriptions/<subscription-id>/resourceGroups/cmhl-preprod-rg \
  --sdk-auth
```
3. Copy the entire JSON output (you'll add this to GitHub secrets)

**To find your subscription ID:**
- Go to "Subscriptions" in Azure Portal
- Copy the "Subscription ID"

## Step 6: Configure GitHub Repository Secrets

1. Go to your GitHub repository
2. Click "Settings" → "Secrets and variables" → "Actions"
3. Click "New repository secret" for each:

| Secret Name | Value | Where to find |
|------------|-------|---------------|
| `AZURE_CREDENTIALS` | JSON output from Step 5 | Service principal creation |
| `DB_HOST` | `keycloak-db.postgres.database.azure.com` | PostgreSQL Overview page |
| `DB_NAME` | `keycloak` | Database you created |
| `DB_USERNAME` | `keycloakadmin` | PostgreSQL admin username |
| `DB_PASSWORD` | Your PostgreSQL password | Password you created |
| `KEYCLOAK_HOSTNAME` | Container App URL (without https://) | Container App Overview |
| `KEYCLOAK_ADMIN` | `admin` | Choose admin username |
| `KEYCLOAK_ADMIN_PASSWORD` | Strong password | Choose admin password |

## Step 7: Update GitHub Workflow

1. Edit `.github/workflows/deploy.yml`
2. Replace these values:
   - `<your-acr-name>`: `chkeycloakacr`
   - `<your-resource-group>`: `cmhl-preprod-rg`

## Step 8: Deploy

1. Commit and push your code to GitHub `main` branch
2. Go to "Actions" tab in GitHub
3. Watch the workflow run
4. After successful deployment, access Keycloak at your Container App URL

## Access Keycloak

- **Application**: `https://<your-container-app-url>`
- **Admin Console**: `https://<your-container-app-url>/admin`
- **Username**: Value from `KEYCLOAK_ADMIN` secret
- **Password**: Value from `KEYCLOAK_ADMIN_PASSWORD` secret

## Troubleshooting

**If deployment fails:**
1. Check GitHub Actions logs
2. Verify all secrets are correctly set
3. Ensure Container App can access PostgreSQL (check firewall rules)
4. Check Container App logs in Azure Portal → Container App → "Monitoring" → "Log stream"

**To view Container App logs:**
1. Go to your Container App in Azure Portal
2. Click "Monitoring" → "Log stream"
3. Check for any errors
