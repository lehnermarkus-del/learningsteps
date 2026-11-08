# Prüfprotokoll – LearningSteps Evolution

Stand: 8. November 2026. Es wurden ausschließlich synthetische Testdaten verwendet. Dieses Projekt wurde nicht bei Cybersteps eingereicht.

## Lokal tatsächlich geprüft

- Docker-Container läuft ohne Root und wird als gesund gemeldet.
- Sechs API-Tests und Ruff erfolgreich (`api-tests.txt`).
- CRUD-Smoke-Test mit echter PostgreSQL-Datenbank erfolgreich (`local-smoke.txt`).
- Trivy: keine HIGH-/CRITICAL-Befunde im Alpine-Image (`image-scan.txt`).
- Trivy: keine HIGH-/CRITICAL-Befunde im aktuellen Terraform-Quellcode (`iac-scan.txt`).
- Gitleaks: keine erkannten Secrets in der Git-Historie (`secret-scan.txt`).
- actionlint: Exitcode 0 (`workflow-validation.txt`).
- Prometheus erfasst `learningsteps_database_up = 1`; Grafana stellt vier Dashboard-Panels bereit (`monitoring-local.json`).

## GitHub-Nachweise

| Prüfung | Ergebnis | Nachweis |
|---|---|---|
| Vollständige CI auf main | Erfolgreich; alle Build-/Scan-Schritte bestanden | [Run 42487870145](https://github.com/lehnermarkus-del/learningsteps/actions/runs/42487870145) |
| Unsichere Key-Vault-Regel | Erwartet fehlgeschlagen im Schritt Terraform-Sicherheitsprüfung; Deployment übersprungen | [Run 42487981048](https://github.com/lehnermarkus-del/learningsteps/actions/runs/42487981048) |
| Verwundbares Django-Paket | Erwartet fehlgeschlagen im Schritt Image-Sicherheitsprüfung; Deployment übersprungen | [Run 42487999394](https://github.com/lehnermarkus-del/learningsteps/actions/runs/42487999394) |

Die absichtlich unsicheren Änderungen liegen ausschließlich auf `test/security-gate` und `test/vulnerability-gate`. Diese Branches sind Nachweise, dürfen nicht in main übernommen oder bereitgestellt werden. Auf main sind diese Änderungen nicht enthalten.

## Azure-Test und Wiederaufbau

Der erste Terraform-Aufbau in Germany West Central konnte AKS, ACR, Netzwerk und Key Vault erstellen. PostgreSQL wurde mit `ParameterOutOfRange` abgelehnt. Die Azure-Capability-Abfrage zeigte: `Provisioning is restricted in this region`. Für West Europe wurde PostgreSQL-Unterstützung bestätigt. Deshalb wird der eigene erste Testaufbau abgebaut und die vollständige Umgebung in West Europe neu erstellt. Ein fehlerfreies `terraform validate` beweist nicht, dass eine Subscription jede konfigurierte Azure-Ressource tatsächlich erstellen darf.

Weitere Live-Ergebnisse werden nach Abschluss des Testlaufs ergänzt. Aus nicht durchgeführten Prüfungen wird kein Erfolg abgeleitet.

## Erstes vollständiges Live-Deployment

Am 8. November 2026 um 15:33 Uhr (Europe/Berlin) bestand der Smoke-Test gegen die Azure-LoadBalancer-IP. Die API meldete den bereitgestellten Commit `1c40845173f190cec54e8241980b6721cce8b9a4`; dieser stimmt mit dem GitHub-Push überein (`azure-deployment-first.json`).

[GitHub-Run 42490045383](https://github.com/lehnermarkus-del/learningsteps/actions/runs/42490045383) ist vollständig erfolgreich: Build, sämtliche Scans, OIDC-Anmeldung, ACR-Push, Migration, Rolling Update und Wiederherstellung der ursprünglichen API-Zugriffsliste. Das Screenshot `github-live-success.png` und die Job-Zusammenfassung `github-live-first.json` dokumentieren den Lauf.

Der Pod `learningsteps-b9d46958f-sp9xp` wurde für einen kontrollierten Selbstheilungstest entfernt. Kubernetes erzeugte `learningsteps-b9d46958f-rmlgn`; anschließend waren wieder zwei API-Replikate bereit (`self-healing-first.json`).

Der HPA erfasste 2 % CPU bei einem Ziel von 70 %, mit 2–4 konfigurierten Replikaten (`hpa-first.txt`). Prometheus meldete beide aktuellen API-Targets als `up`, ohne Scrape-Fehler. Das deutsche Grafana-Dashboard mit vier Panels war in AKS abrufbar (`grafana-aks-dashboard.json`).

Ein zusätzlicher lokaler Test mit vorübergehendem Stoppen der Datenbank wurde von der automatischen Sicherheitsprüfung blockiert; eine genauere Begründung wurde nicht angegeben. Er wurde nicht durchgeführt. Der stateless Kubernetes-Pod-Test war erfolgreich, und die automatisierten Readiness-Tests prüfen HTTP 503 bei einem Datenbankfehler.

## Vollständiger Wiederherstellungszyklus

`terraform destroy` entfernte am 8. November 2026 alle 27 Ressourcen des ersten vollständigen Aufbaus. Der Terraform-State war danach leer. Anschließend lief `terraform apply` mit unverändertem Infrastrukturcode erfolgreich durch und erstellte die Umgebung erneut. Start- und Abschlusszeiten stehen in `recovery-cycle.txt`; `recovery-code-integrity.txt` enthält den unveränderten Git-Tree des Infrastrukturverzeichnisses.

Für den anschließenden CD-Nachweis wurde ausschließlich die Anwendung sichtbar erweitert: `/health/live` nennt nun zusätzlich den Dienst `LearningSteps Evolution`. Die erneute Bereitstellung wird über GitHub Actions ausgelöst und danach gegen die neue öffentliche IP geprüft.

## Ergebnis nach dem Wiederaufbau

[GitHub-Run 42492096888](https://github.com/lehnermarkus-del/learningsteps/actions/runs/42492096888) ist vollständig erfolgreich, einschließlich beider Prüf- und Deployment-Jobs sowie der Rücknahme der temporären Runner-IP.

Der erneute Smoke-Test bestand am 8. November 2026 um 15:58 Uhr (Europe/Berlin). `/health/live` lieferte den neuen Dienstnamen `LearningSteps Evolution` und Commit `ede2e14f60eabc9fbbd6a87f9e3bc5d717cfc251`. Damit ist die bewusst geänderte Anwendung nach einem GitHub-Push automatisch auf der neu aufgebauten Azure-Umgebung angekommen (`azure-deployment-recovery.json`, `azure-smoke-recovery.txt`).

Prometheus meldete erneut zwei aktuelle Scrape-Targets als `up`, ohne Fehler. Der HPA erfasste erneut 2 % CPU bei einem Ziel von 70 % und zwei Replikaten (`monitoring-recovery-targets.json`, `hpa-recovery.txt`). Auch Prometheus und Grafana wurden im neuen Cluster wieder installiert.

Nach dem erfolgreichen unveränderten Wiederaufbau wurde der von PostgreSQL automatisch ergänzte Microsoft.Storage-Endpunkt des Datenbank-Subnetzes ausdrücklich in den Code übernommen. Ein anschließender Terraform-Plan bestätigte erneut vollständige Übereinstimmung ohne Änderungen an Azure (`recovery-no-drift.txt`). Der Wiederherstellungsnachweis selbst bezieht sich auf den unveränderten Infrastrukturcode im Commit ede2e14; die Ergänzung erfolgte danach.

Die Cloud-Testumgebung wird anschließend endgültig abgebaut und automatisches Deployment deaktiviert. Die lokale Compose-Vorschau bleibt für die Prüfung verfügbar. Alle Nachweise stammen aus real ausgeführten Prüfungen; hohe Last oder tatsächliches HPA-Hochskalieren wurden nicht getestet.

## Endzustand und Abgabe

Der abschließende `terraform destroy` entfernte erneut alle 27 Ressourcen. Der State ist leer, und die Azure-Abfrage zeigt keine aktiven Ressourcengruppen des Projekts mehr (`final-cleanup.txt`, `azure-final-state.json`). Key Vaults unterliegen weiterhin dem bewusst aktivierten Soft-Delete-/Purge-Schutz; sie sind nicht aktiv bereitgestellt.

Automatisches Deployment ist im finalen Stand deaktiviert. Die CI bleibt aktiv. Die früheren öffentlichen Test-IPs sind nach dem Abbau nicht mehr erreichbar. Eine genaue Azure-Rechnung liegt wegen der verzögerten Kostenanzeige noch nicht vor; die aufgezeichneten Compute-Listenpreise sind keine Abrechnung.

Es wurde nichts bei Cybersteps eingereicht. Das Abgabe-ZIP wird ausschließlich aus den versionierten Dateien des finalen main-Standes erzeugt. Lokale Zugangsdaten, .env, Kubeconfig und Terraform-State sind ausgeschlossen.
