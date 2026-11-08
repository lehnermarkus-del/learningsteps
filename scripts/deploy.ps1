param([Parameter(Mandatory)][string]$ImageTag, [Parameter(Mandatory)][string]$ClientCidr)
$ErrorActionPreference = 'Stop'
function Check { if ($LASTEXITCODE -ne 0) { throw 'Vorheriger Befehl fehlgeschlagen' } }
$config = terraform -chdir=infra-terraform output -json deployment | ConvertFrom-Json
Check
az aks get-credentials -g $config.resource_group -n $config.cluster --file "$PWD/.kubeconfig" --overwrite-existing
Check
$env:KUBECONFIG = "$PWD/.kubeconfig"
$env:IMAGE = "$($config.login_server)/learningsteps:$ImageTag"
$env:APP_CLIENT_ID = $config.app_client_id
$env:KEY_VAULT_NAME = $config.vault
$env:TENANT_ID = $config.tenant
$env:CLIENT_CIDR = $ClientCidr
# Python läuft aus dem bereits gebauten Image, auch ohne lokale Python-Installation.
docker run --rm -e IMAGE -e APP_CLIENT_ID -e KEY_VAULT_NAME -e TENANT_ID -e CLIENT_CIDR -v "${PWD}:/workspace" -w /workspace learningsteps:local python scripts/render.py
Check
kubectl apply -f rendered/application.yaml
Check
kubectl delete job learningsteps-migrate -n learningsteps --ignore-not-found
kubectl apply -f rendered/migration.yaml
Check
kubectl wait -n learningsteps --for=condition=complete job/learningsteps-migrate --timeout=180s
Check
kubectl rollout status -n learningsteps deployment/learningsteps --timeout=240s
Check
kubectl get pods,svc,hpa -n learningsteps
