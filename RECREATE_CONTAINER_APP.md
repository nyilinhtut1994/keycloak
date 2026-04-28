# Delete and Recreate Container App Guide

## Step 1: Delete Existing Container App

1. Go to Azure Portal (https://portal.azure.com)
2. Search for "Container Apps"
3. Find and click on `keycloak-app`
4. Click "Delete" at the top
5. Type the app name to confirm and click "Delete"
6. Wait for deletion to complete (1-2 minutes)

## Step 2: Create New Container App with ACR Integration

1. Search for "Container Apps" → Click "Create"
2. On the "Basics" tab:
   - **Resource group**: `cmhl-preprod-rg`
   - **Container app name**: `keycloak-app`
   - **Region**: Same as your resource group
3. Under "Container Apps Environment":
   - Select existing: `keycloak-env`
4. Click "Next: Container"
5. On the "Container" tab:
   - Uncheck "Use quickstart image"
   - **Name**: `keycloak`
   - **Image source**: `Azure Container Registry`
   - **Registry**: Select `chkeycloakacr`
   - **Image**: `keycloak`
   - **Image tag**: `latest`
   - **CPU and Memory**: `1 CPU cores, 2 Gi memory`
6. Click "Next: Ingress"
7. On the "Ingress" tab:
   - Check "Enabled"
   - **Ingress traffic**: `Accepting traffic from anywhere`
   - **Ingress type**: `HTTP`
   - **Target port**: `8080`
8. Click "Review + create" → "Create" (takes 3-5 minutes)
9. After creation:
   - Go to the Container App
   - Click "Overview"
   - Copy the "Application URL"
   - Update your GitHub secret `KEYCLOAK_HOSTNAME` with this URL (without https://)

## Step 3: Enable System-Assigned Managed Identity

1. In your Container App, go to "Settings" → "Identity"
2. Under "System assigned" tab:
   - Toggle "Status" to "On"
   - Click "Save"
   - Click "Yes" to confirm
3. Wait for the identity to be created

## Step 4: Grant ACR Pull Permission to Container App

1. Go to your ACR: `chkeycloakacr`
2. Click "Access control (IAM)" in left menu
3. Click "+ Add" → "Add role assignment"
4. On "Role" tab:
   - Search and select "AcrPull"
   - Click "Next"
5. On "Members" tab:
   - Select "Managed identity"
   - Click "+ Select members"
   - Under "Managed identity", select "Container App"
   - Select `keycloak-app`
   - Click "Select"
   - Click "Next"
6. Click "Review + assign"

## Step 5: Trigger GitHub Actions Deployment

1. Go to your GitHub repository: https://github.com/City-Holdings-MM/city-keycloak
2. Click "Actions" tab
3. Click "Deploy Keycloak to Azure Container Apps"
4. Click "Run workflow" → "Run workflow"
5. Wait for deployment to complete

## Verification

After deployment completes:
- Access: `https://<your-container-app-url>`
- Admin Console: `https://<your-container-app-url>/admin`
- Login with your `KEYCLOAK_ADMIN` credentials

## Notes

- The Container App now uses system-assigned managed identity to pull from ACR
- No need to store ACR credentials as secrets
- The workflow will automatically update the app on every push to main branch
