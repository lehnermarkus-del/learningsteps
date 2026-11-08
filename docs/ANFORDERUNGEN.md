# Zuordnung der Anforderungen

| Anforderung | Umsetzung | Tatsächlicher Nachweis |
|---|---|---|
| Produktionsnahes Container-Image | Gepinntes Alpine-Basisimage, feste Python-Versionen, Non-Root, Healthcheck, gezielte COPY-Anweisungen | Lokaler Container gesund; Trivy ohne HIGH/CRITICAL; GitHub-CI erfolgreich |
| Lokal bauen und testen | Compose mit PostgreSQL-Healthcheck und persistentem Volume; lokale Ports nur an Loopback | Sechs API-Tests und realer CRUD-Smoke-Test |
| ACR | Basic Registry ohne Admin-Passwort; Managed Identity für Pull, OIDC für Push | Erfolgreicher ACR-Push im Live-Workflow |
| Netzwerk | VNet mit getrennten AKS-/PostgreSQL-Subnetzen, Private DNS, private Datenbank | Azure-Aufbau und erfolgreiche SQL-Zugriffe aus den Pods |
| AKS | Ein temporärer Budget-Knoten, Deployment mit zwei Replikaten | Knoten Ready, zwei API-Pods Ready |
| Key Vault | Datenbank-DSN im Vault, Firewall, Secret-spezifische RBAC, Workload Identity und CSI | API und Migration verbinden sich ohne Klartext-Secret im Manifest |
| Secret Scanning | Gitleaks über Git-Historie | CI erfolgreich und lokaler Scan ohne erkannte Secrets |
| Schwachstellen-Scan | Trivy für Image; HIGH/CRITICAL führt zu Exitcode 1 | Negativbranch mit Django 2.2.0 scheitert am Image-Scan |
| IaC-Sicherheitsprüfung | Trivy config | Negativbranch mit offener Key-Vault-ACL scheitert am IaC-Scan |
| CI/CD | Jeder Push: Lint, Tests, Terraform-Validierung, Scans, Build; main mit aktivem Testfenster: Push und Deployment | GitHub-Run 42490045383 vollständig erfolgreich |
| Deployment, Service, ConfigMap | k8s-manifests/application.yaml | Live-Smoke-Test an Azure-LoadBalancer-IP |
| Selbstheilung | Kubernetes Deployment, Startup-/Liveness-/Readiness-Probes | Entfernten stateless API-Pod durch neuen bereiten Pod ersetzt |
| Skalierbarkeit | autoscaling/v2 HPA, CPU 70 %, 2–4 Replikate | HPA erfasst CPU-Werte; keine Lastspitze oder tatsächliche Hochskalierung behauptet |
| Monitoring (optional) | prometheus_client, kube-prometheus-stack, vier deutsche Grafana-Panels | Zwei aktuelle API-Scrape-Targets up; Datenbankstatus 1; Dashboard in AKS abrufbar |
| Wiederherstellung | terraform destroy und terraform apply mit unverändertem Infrastrukturcode | Abschluss im Prüfprotokoll und recovery-cycle.txt |
| Technische Dokumentation | README, Betriebs-/Testskripte, Prüfprotokoll, Quellen | Deutsch; Grenzen und offene Dauerbetriebs-Themen ausdrücklich dokumentiert |
