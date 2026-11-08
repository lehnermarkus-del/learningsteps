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
