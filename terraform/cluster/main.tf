# ---------------------------------------------------------------------------
# Disposable infrastructure: the AKS cluster.
#
# Separate root module, separate state file. `terraform destroy` here removes
# the cluster and stops the node VM billing, and cannot touch the registry -
# that lives in terraform/registry/'s state and this module never owns it.
#
# Requires terraform/registry to have been applied first.
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# ---------------------------------------------------------------------------
# Data sources: read existing infrastructure without owning it.
#
# `resource` means "make this exist and manage its lifecycle".
# `data`     means "go look this up, I just need to read from it".
#
# This is the seam between the two modules. Terraform can also read another
# module's state directly (terraform_remote_state), but looking things up by
# name keeps the modules independent - this one only needs the registry to
# exist, not to know where its state file lives.
#
# If the registry has not been created yet, `plan` fails immediately with a
# clear "not found" rather than building half a cluster.
# ---------------------------------------------------------------------------
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

data "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = data.azurerm_resource_group.main.name
}

# ---------------------------------------------------------------------------
# The cluster - `az aks create`.
#
# AKS also creates a second resource group of its own, named MC_<rg>_<cluster>_<region>,
# holding the node VM scale set, load balancer, public IPs, vnet and NSG. You do
# not manage that group; it is created and destroyed along with the cluster.
# That is where essentially all of the cost lives.
# ---------------------------------------------------------------------------
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name

  # Part of the cluster's public API hostname. Must be unique within the region.
  dns_prefix = var.cluster_name

  # "Free" gives an unmanaged-SLA control plane at no charge. "Standard" adds a
  # financially backed SLA for about $0.10/cluster/hour. Either way you pay for
  # the nodes below - the tier only prices the control plane.
  sku_tier = "Free"

  # The second scaling layer: the cluster autoscaler.
  #
  # The HPA in k8s/hpa.yaml adds pods. It does not add machines. When a pod
  # cannot be placed because no node has room, it sits in Pending with
  # "Insufficient cpu" - the HPA did its job, there was just nowhere to put it.
  #
  # With auto-scaling on, the cluster autoscaler watches for exactly that and
  # adds a node, then removes it again once it has been underused for ~10
  # minutes. min_count = 1 means you always pay for one node; scaling to zero
  # is not possible for a cluster's only node pool.
  default_node_pool {
    name    = "default"
    vm_size = var.node_vm_size

    auto_scaling_enabled = true
    min_count            = var.node_min_count
    max_count            = var.node_max_count

    # With auto-scaling on this is only the STARTING size. Azure changes it
    # afterwards, which is why it is ignored below - otherwise every plan would
    # want to shrink your cluster back to the number written here.
    node_count = var.node_min_count
  }

  # A managed identity for the cluster, created and rotated by Azure. The
  # alternative is a service principal with a password you have to rotate
  # yourself. There is no reason to choose that.
  identity {
    type = "SystemAssigned"
  }

  tags = var.tags

  # Terraform's answer to "something else legitimately changes this field".
  #
  # The cluster autoscaler adjusts node_count at runtime. Without this block,
  # Terraform would see 3 nodes where the config says 1, call it drift, and
  # offer to scale you back down on every single plan. ignore_changes tells it
  # to stop caring about that one attribute after creation.
  #
  # Use this sparingly - it is a deliberate blind spot in your state.
  lifecycle {
    ignore_changes = [default_node_pool[0].node_count]
  }
}

# ---------------------------------------------------------------------------
# THIS IS `--attach-acr`.
#
# When you ran `az aks create --attach-acr` by hand, this role assignment is
# all it did: grant the cluster's kubelet identity permission to pull from the
# registry. Nothing more magical than that.
#
# It is also the reason the GitHub service principal needed "Role Based Access
# Control Administrator" and not just "Contributor" - Contributor can create
# almost anything, but explicitly cannot create role assignments. Otherwise any
# Contributor could quietly promote themselves to Owner.
#
# Note the two references below. `scope` points at the data source, `principal_id`
# at the cluster resource. Those references are what tell Terraform this must be
# created after the cluster exists - the ordering is never written by hand.
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "aks_pull_from_acr" {
  scope                = data.azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id

  # The kubelet identity is brand new at this point, and Entra takes a few
  # seconds to replicate it. Without this, apply intermittently fails claiming
  # the principal does not exist. Skipping the check is the documented fix.
  skip_service_principal_aad_check = true
}
