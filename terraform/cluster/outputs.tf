# ---------------------------------------------------------------------------
# Outputs.
# ---------------------------------------------------------------------------

output "cluster_name" {
  description = "AKS cluster name."
  value       = azurerm_kubernetes_cluster.aks.name
}

output "resource_group_name" {
  description = "Resource group holding the cluster."
  value       = data.azurerm_resource_group.main.name
}

output "node_resource_group" {
  description = <<-EOT
    The MC_* group AKS creates for itself. Holds the node scale set, load
    balancer, public IPs, vnet and NSG - almost all of the actual cost.
    Never delete this by hand; it goes away with the cluster.
  EOT
  value = azurerm_kubernetes_cluster.aks.node_resource_group
}

output "get_credentials_command" {
  description = "Run this to point your local kubectl at the cluster."
  value       = "az aks get-credentials --resource-group ${data.azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.aks.name} --overwrite-existing"
}
