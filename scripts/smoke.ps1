param([string]$BaseUrl = 'http://localhost:8000')
$ErrorActionPreference = 'Stop'
function Assert($Condition, $Message) { if (!$Condition) { throw $Message } }
$ready = Invoke-RestMethod "$BaseUrl/health/ready"
Assert ($ready.status -eq 'ready') 'Readiness fehlgeschlagen'
$body = @{work='Terraform und Kubernetes';struggle='Private DNS';intention='Automatisierte Tests'} | ConvertTo-Json
$created = Invoke-RestMethod "$BaseUrl/entries" -Method Post -ContentType application/json -Body $body
$id = $created.entry.id
Assert ($id.Length -gt 0) 'ID fehlt'
$entry = Invoke-RestMethod "$BaseUrl/entries/$id"
Assert ($entry.work -eq 'Terraform und Kubernetes') 'Lesen fehlgeschlagen'
$updated = Invoke-RestMethod "$BaseUrl/entries/$id" -Method Patch -ContentType application/json -Body '{"work":"Erfolgreich getestet"}'
Assert ($updated.struggle -eq 'Private DNS') 'PATCH hat andere Felder verloren'
$list = Invoke-RestMethod "$BaseUrl/entries"
Assert ($list.count -ge 1) 'Liste leer'
Invoke-RestMethod "$BaseUrl/entries/$id" -Method Delete | Out-Null
$missing = Invoke-WebRequest "$BaseUrl/entries/$id" -SkipHttpErrorCheck
Assert ($missing.StatusCode -eq 404) 'Gelöschter Eintrag noch vorhanden'
$metrics = (Invoke-WebRequest "$BaseUrl/metrics").Content
Assert ($metrics.Contains('learningsteps_http_requests_total')) 'Metriken fehlen'
Write-Output "PASS: Readiness, Erstellen, Lesen, PATCH-Felderhalt, Auflisten, Löschen/404 und Metriken ($BaseUrl)"
