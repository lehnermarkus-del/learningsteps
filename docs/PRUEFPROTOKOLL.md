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
