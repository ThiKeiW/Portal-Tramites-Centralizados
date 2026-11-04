# Despliegue del backend en Azure Container Apps (Central US, SIEMPRE ACTIVO).
# Requiere: az CLI autenticada (az login), imagen publicada en Docker Hub y
# backend/.env.local con las credenciales (DB_*, DEEPGRAM_API_KEY).
#
# Uso:
#   .\deploy\az-backend.ps1 -DockerUser <usuario-dockerhub> [-YaEnElHub]
#
# Los secretos se leen de backend/.env.local y JAMAS se imprimen en consola.
param(
    [Parameter(Mandatory = $true)][string]$DockerUser,
    [switch]$YaEnElHub = $false
)

$ErrorActionPreference = "Stop"
$RG = "rg-portal-tramites"
$ENV_NAME = "cae-portal-tramites"
$APP = "ca-portal-backend"
$LOCATION = "eastus2"
$IMAGE = "$DockerUser/portal-backend:1.0"
$SWA_DOMINIO = "https://swa-portal-frontend-tk.azurestaticapps.net"

# ---------- 0. Credenciales (sin imprimir valor alguno) ----------
$backendDir = Join-Path $PSScriptRoot "..\backend"
$envLocal = @{}
Get-Content (Join-Path $backendDir ".env.local") | ForEach-Object {
    if ($_ -match '^([A-Za-z_]+)=(.*)$') { $envLocal[$matches[1]] = $matches[2] }
}
$requeridos = @('DB_HOST', 'DB_PORT', 'DB_NAME', 'DB_USER', 'DB_PASSWORD', 'DB_SSL_PARAMS', 'DEEPGRAM_API_KEY')
foreach ($k in $requeridos) {
    if (-not $envLocal[$k]) { throw "FALTA la clave $k en backend/.env.local" }
}

# ---------- 1. Build y push a Docker Hub ----------
if (-not $YaEnElHub) {
    Push-Location $backendDir
    docker build -t $IMAGE .
    if ($LASTEXITCODE -ne 0) { Pop-Location; throw "docker build fallo" }
    Pop-Location
    docker push $IMAGE
    if ($LASTEXITCODE -ne 0) { throw "docker push fallo (verifica: docker login)" }
}
Write-Host "Imagen en Hub: $IMAGE"

# ---------- 2. Grupo de recursos + entorno Container Apps ----------
az account show --query "name" -o tsv
az group create --name $RG --location $LOCATION
az containerapp env create `
    --name $ENV_NAME `
    --resource-group $RG `
    --location $LOCATION | Out-Null

# ---------- 3. App: SIEMPRE ACTIVA (min-replicas 1), HTTPS publico ----------
az containerapp create `
    --name $APP `
    --resource-group $RG `
    --environment $ENV_NAME `
    --image $IMAGE `
    --target-port 8080 `
    --ingress external `
    --min-replicas 1 `
    --max-replicas 1 `
    --cpu 0.5 `
    --memory 1.0Gi | Out-Null

# ---------- 4. Variables de entorno (credenciales al runtime) ----------
$vars = @(
    "DB_HOST=$($envLocal['DB_HOST'])",
    "DB_PORT=$($envLocal['DB_PORT'])",
    "DB_NAME=$($envLocal['DB_NAME'])",
    "DB_USER=$($envLocal['DB_USER'])",
    "DB_PASSWORD=$($envLocal['DB_PASSWORD'])",
    "DB_SSL_PARAMS=$($envLocal['DB_SSL_PARAMS'])",
    "DEEPGRAM_API_KEY=$($envLocal['DEEPGRAM_API_KEY'])",
    "CORS_ORIGINS=$SWA_DOMINIO,http://localhost:5173"
)
az containerapp update `
    --name $APP `
    --resource-group $RG `
    --set-env-vars @vars | Out-Null
Write-Host "Variables de entorno aplicadas (no se muestran por seguridad)."

# ---------- 5. URL publica ----------
$FQDN = az containerapp show --name $APP --resource-group $RG --query "properties.configuration.ingress.fqdn" -o tsv
Write-Host ""
Write-Host "BACKEND DESPLEGADO: https://$FQDN"
Write-Host "Prueba: curl https://$FQDN/api/tipos"
Write-Host "Revisar arranque (busca 'Catalogo precargado'):"
Write-Host "  az containerapp logs show --name $APP --resource-group $RG --tail 200"
