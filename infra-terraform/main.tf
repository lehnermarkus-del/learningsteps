terraform {
  required_version = ">= 1.7, < 2"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.51" }
    random  = { source = "hashicorp/random", version = "~> 3.7" }
  }
}
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }
  subscription_id = var.subscription_id
}
data "azurerm_client_config" "current" {}
variable "subscription_id" { type = string }
variable "location" { default = "westeurope" }
variable "prefix" { default = "lsevo" }
variable "admin_cidr" {
  type        = string
  description = "Öffentliche IPv4 des ausführenden Rechners als /32, keine offene API"
  validation {
    condition     = can(cidrhost(var.admin_cidr, 0)) && endswith(var.admin_cidr, "/32")
    error_message = "Eine einzelne IPv4 als /32 angeben."
  }
}
variable "node_size" { default = "Standard_D2s_v5" }
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}
locals {
  name    = "${var.prefix}-${random_string.suffix.result}"
  compact = "${var.prefix}${random_string.suffix.result}"
}
resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name}"
  location = var.location
  tags     = { project = "LearningSteps-Evolution", lifecycle = "temporary-test" }
}
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${local.name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  address_space       = ["10.42.0.0/16"]
}
resource "azurerm_subnet" "aks" {
  service_endpoints    = ["Microsoft.KeyVault"]
  name                 = "aks"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.42.0.0/22"]
}
resource "azurerm_subnet" "db" {
  name                 = "postgres"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.42.4.0/24"]
  delegation {
    name = "postgres"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}
resource "azurerm_private_dns_zone" "db" {
  name                = "${local.compact}.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.main.name
}
resource "azurerm_private_dns_zone_virtual_network_link" "db" {
  name                  = "postgres"
  private_dns_zone_name = azurerm_private_dns_zone.db.name
  resource_group_name   = azurerm_resource_group.main.name
  virtual_network_id    = azurerm_virtual_network.main.id
}
resource "random_password" "db" {
  length  = 32
  special = false
}
resource "azurerm_postgresql_flexible_server" "db" {
  name                          = "pg-${local.name}"
  resource_group_name           = azurerm_resource_group.main.name
  location                      = var.location
  version                       = "16"
  delegated_subnet_id           = azurerm_subnet.db.id
  private_dns_zone_id           = azurerm_private_dns_zone.db.id
  public_network_access_enabled = false
  administrator_login           = "learningsteps"
  administrator_password        = random_password.db.result
  sku_name                      = "B_Standard_B1ms"
  storage_mb                    = 32768
  backup_retention_days         = 7
  depends_on                    = [azurerm_private_dns_zone_virtual_network_link.db]
}
resource "azurerm_postgresql_flexible_server_database" "app" {
  name      = "learningsteps"
  server_id = azurerm_postgresql_flexible_server.db.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}
resource "azurerm_container_registry" "main" {
  name                = "acr${local.compact}"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = false
}
resource "azurerm_user_assigned_identity" "aks" {
  name                = "id-aks-${local.name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
}
resource "azurerm_role_assignment" "network" {
  scope                = azurerm_virtual_network.main.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}
resource "azurerm_kubernetes_cluster" "main" {
  name                              = "aks-${local.name}"
  resource_group_name               = azurerm_resource_group.main.name
  location                          = var.location
  dns_prefix                        = local.name
  sku_tier                          = "Free"
  role_based_access_control_enabled = true
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  default_node_pool {
    name                        = "system"
    node_count                  = 1
    vm_size                     = var.node_size
    vnet_subnet_id              = azurerm_subnet.aks.id
    os_disk_size_gb             = 32
    temporary_name_for_rotation = "rotation"
  }
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }
  api_server_access_profile { authorized_ip_ranges = [var.admin_cidr] }
  key_vault_secrets_provider { secret_rotation_enabled = true }
  network_profile {
    network_plugin    = "azure"
    network_policy    = "azure"
    service_cidr      = "10.43.0.0/16"
    dns_service_ip    = "10.43.0.10"
    load_balancer_sku = "standard"
  }
  depends_on = [azurerm_role_assignment.network]
}
resource "azurerm_role_assignment" "pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}
resource "azurerm_key_vault" "main" {
  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    ip_rules                   = [var.admin_cidr]
    virtual_network_subnet_ids = [azurerm_subnet.aks.id]
  }
  name                       = "kv-${local.name}"
  resource_group_name        = azurerm_resource_group.main.name
  location                   = var.location
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true

  purge_protection_enabled   = true
  soft_delete_retention_days = 7
}
resource "azurerm_role_assignment" "vault_operator" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}
resource "azurerm_key_vault_secret" "database_url" {
  name         = "database-url"
  value        = "postgresql://learningsteps:${random_password.db.result}@${azurerm_postgresql_flexible_server.db.fqdn}:5432/learningsteps?sslmode=require"
  key_vault_id = azurerm_key_vault.main.id
  depends_on   = [azurerm_role_assignment.vault_operator, azurerm_postgresql_flexible_server_database.app]
}
resource "azurerm_user_assigned_identity" "app" {
  name                = "id-app-${local.name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
}
resource "azurerm_federated_identity_credential" "app" {
  name                = "learningsteps"
  resource_group_name = azurerm_resource_group.main.name
  parent_id           = azurerm_user_assigned_identity.app.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.main.oidc_issuer_url
  subject             = "system:serviceaccount:learningsteps:learningsteps"
}
resource "azurerm_role_assignment" "app_vault" {
  scope                = azurerm_key_vault_secret.database_url.resource_versionless_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.app.principal_id
}
output "deployment" {
  value = {
    resource_group = azurerm_resource_group.main.name
    cluster        = azurerm_kubernetes_cluster.main.name
    registry       = azurerm_container_registry.main.name
    login_server   = azurerm_container_registry.main.login_server
    vault          = azurerm_key_vault.main.name
    tenant         = data.azurerm_client_config.current.tenant_id
    app_client_id  = azurerm_user_assigned_identity.app.client_id
  }
}




