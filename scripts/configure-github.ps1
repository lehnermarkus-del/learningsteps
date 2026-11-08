param([switch]$Enable)
$ErrorActionPreference = 'Stop'
$config = terraform -chdir=infra-terraform output -json deployment | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw 'Terraform-Ausgaben fehlen' }
$github = terraform -chdir=infra-terraform output -json github | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) { throw 'GitHub-Identität fehlt' }
@{
  enabled = [bool]$Enable
  client_id = $github.client_id
  subscription_id = $github.subscription_id
  resource_group = $config.resource_group
  cluster = $config.cluster
  registry = $config.registry
  app_client_id = $config.app_client_id
  vault = $config.vault
  tenant = $config.tenant
} | ConvertTo-Json | Set-Content deployment-config.json
Write-Output 'Deployment-Konfiguration geschrieben. Erst nach Commit/Push wirksam.'
