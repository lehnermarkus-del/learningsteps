param([string]$ChartVersion = '69.8.2')
$ErrorActionPreference = 'Stop'
if (!(Test-Path .kubeconfig)) { throw 'Zuerst scripts/deploy.ps1 ausführen' }
kubectl --kubeconfig .kubeconfig create namespace monitoring --dry-run=client -o yaml | kubectl --kubeconfig .kubeconfig apply -f -
kubectl --kubeconfig .kubeconfig -n monitoring create configmap learningsteps-dashboard --from-file=learningsteps.json=monitoring/dashboard.json --dry-run=client -o yaml | kubectl --kubeconfig .kubeconfig apply -f -
kubectl --kubeconfig .kubeconfig -n monitoring label configmap learningsteps-dashboard grafana_dashboard=1 --overwrite
# Chart aus dem offiziellen Prometheus-Community-Repository; Passwort wird vom Chart generiert.
docker run --rm -v "${PWD}:/workspace" -e KUBECONFIG=/workspace/.kubeconfig --entrypoint sh alpine/helm:3.17.3 -c "helm repo add prometheus-community https://prometheus-community.github.io/helm-charts && helm upgrade --install monitoring prometheus-community/kube-prometheus-stack --version $ChartVersion -n monitoring -f /workspace/monitoring/values.yaml --wait --timeout 5m"
if ($LASTEXITCODE -ne 0) { throw 'Monitoring-Installation fehlgeschlagen' }
Write-Output 'Grafana öffnen: kubectl --kubeconfig .kubeconfig -n monitoring port-forward svc/monitoring-grafana 3001:80'
