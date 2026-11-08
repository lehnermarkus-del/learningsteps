# Azure-Vorabprüfung

Am 8. November 2026 geprüft:

- Germany West Central: PostgreSQL Flexible Server für dieses Abonnement eingeschränkt.
- West Europe: PostgreSQL 16 verfügbar; Server und Datenbank erfolgreich erstellt.
- Standard_D2s_v5: kein freies Familienkontingent in West Europe.
- Standard_D2s_v3: trotz freiem Kontingent nicht für dieses Abonnement verfügbar.
- Standard_D2s_v7: laut Azure-SKU-Abfrage ohne Einschränkungen, x64, 2 vCPU, 8 GiB RAM; Familienkontingent 10, davon 0 belegt zum Prüfzeitpunkt.
- Offizieller Azure-Retailpreis des gewählten Linux-Compute: 0,1481 EUR pro Stunde; separate Nebenkosten für DB, Disk, LB, IP und Registry. Rohdaten: azure-compute-price.json. Diese Werte sind keine Rechnung.

Vor einem späteren Aufbau sind Verfügbarkeit, Kontingente und Preise erneut zu prüfen. Sie können sich unabhängig von der Terraform-Konfiguration ändern.
