resource "azurerm_user_assigned_identity" "github" {
  name                = "id-github-${local.name}"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
}
resource "azurerm_federated_identity_credential" "github" {
  name                = "github-azure"
  resource_group_name = azurerm_resource_group.main.name
  parent_id           = azurerm_user_assigned_identity.github.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = "https://token.actions.githubusercontent.com"
  subject             = "repo:lehnermarkus-del/learningsteps:environment:azure"
}
resource "azurerm_role_assignment" "github_acr" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPush"
  principal_id         = azurerm_user_assigned_identity.github.principal_id
}
resource "azurerm_role_assignment" "github_aks" {
  scope                = azurerm_kubernetes_cluster.main.id
  role_definition_name = "Azure Kubernetes Service Contributor Role"
  principal_id         = azurerm_user_assigned_identity.github.principal_id
}
output "github" {
  value = {
    client_id       = azurerm_user_assigned_identity.github.client_id
    subscription_id = var.subscription_id
  }
}

