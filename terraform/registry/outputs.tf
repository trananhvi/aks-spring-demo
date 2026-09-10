# ---------------------------------------------------------------------------
# Outputs.
#
# Values printed after `apply`, and readable any time with `terraform output`
# or `terraform output -raw acr_login_server` for a script-friendly form.
#
# Outputs are how one root module publishes facts about what it built.
# terraform/cluster/ does not read these directly - it looks the registry up by
# name with a data source instead, which keeps the two modules independent.
# ---------------------------------------------------------------------------

output "acr_login_server" {
  description = "Registry hostname, e.g. quayvitrankms.azurecr.io - the prefix for every image tag."
  value       = azurerm_container_registry.acr.login_server
}

output "acr_name" {
  description = "Short registry name. This is what `az acr login --name` expects."
  value       = azurerm_container_registry.acr.name
}

output "acr_id" {
  description = "Full Azure resource ID. The cluster module needs this to scope the AcrPull grant."
  value       = azurerm_container_registry.acr.id
}

output "resource_group_name" {
  description = "Resource group name, for the cluster module and for az commands."
  value       = azurerm_resource_group.main.name
}

# ---------------------------------------------------------------------------
# These three go into the GitHub repository secrets. None of them are secret in
# any real sense - they are identifiers, useless to anyone without the
# federated trust rule that names your specific repo and branch. Storing them
# as secrets is convention, and keeps them out of logs.
# ---------------------------------------------------------------------------

output "github_client_id" {
  description = "AZURE_CLIENT_ID - the managed identity GitHub Actions authenticates as."
  value       = azurerm_user_assigned_identity.github.client_id
}

output "github_tenant_id" {
  description = "AZURE_TENANT_ID."
  value       = azurerm_user_assigned_identity.github.tenant_id
}

output "github_subscription_id" {
  description = "AZURE_SUBSCRIPTION_ID."
  value       = var.subscription_id
}

output "github_identity_name" {
  description = "Managed identity name, for the cluster module's data source lookup."
  value       = azurerm_user_assigned_identity.github.name
}

