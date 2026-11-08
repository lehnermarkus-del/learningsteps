param([string]$Location = 'westeurope', [string]$VmSize = 'Standard_D2s_v7')
$ErrorActionPreference = 'Stop'
function Check { if ($LASTEXITCODE -ne 0) { throw 'Azure-Abfrage fehlgeschlagen' } }
$pg = az postgres flexible-server list-skus -l $Location -o json | ConvertFrom-Json
Check
if ($pg[0].reason -match 'restricted') { throw "PostgreSQL ist in $Location für dieses Abonnement eingeschränkt: $($pg[0].reason)" }
if (!($pg[0].supportedServerVersions | Where-Object name -eq '16')) { throw 'PostgreSQL 16 nicht verfügbar' }
$skus = az vm list-skus -l $Location --resource-type virtualMachines --size $VmSize --all -o json | ConvertFrom-Json
Check
$sku = $skus | Where-Object name -eq $VmSize
if (!$sku -or ($sku.restrictions | Where-Object type -eq 'Location')) { throw "$VmSize ist in $Location nicht für dieses Abonnement verfügbar" }
$usage = az vm list-usage -l $Location -o json | ConvertFrom-Json
Check
$quota = $usage | Where-Object { $_.name.value -eq $sku.family }
if (!$quota -or ([int]$quota.limit - [int]$quota.currentValue) -lt 2) { throw "Zu wenig freies CPU-Kontingent für $($sku.family)" }
Write-Output "PASS: PostgreSQL 16, VM $VmSize und mindestens 2 freie Familien-vCPUs in $Location bestätigt."
