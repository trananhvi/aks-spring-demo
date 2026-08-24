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
  description = "Registry hostname, e.g. quayvitran.azurecr.io - the prefix for every image tag."
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
