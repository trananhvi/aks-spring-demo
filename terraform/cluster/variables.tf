# ---------------------------------------------------------------------------
# Input variables.
#
# resource_group_name and acr_name must match the values in
# terraform/registry/variables.tf - this module looks those resources up by name.
# ---------------------------------------------------------------------------

variable "subscription_id" {
  description = "Azure subscription to build in."
  type        = string
  default     = "09edd562-ff99-4aa1-a4c6-a093ce9d79b2"
}

variable "resource_group_name" {
  description = "Existing resource group created by terraform/registry."
  type        = string
  default     = "aks-spring-demo"
}

variable "acr_name" {
  description = "Existing container registry created by terraform/registry."
  type        = string
  default     = "quayvitran"
}

variable "cluster_name" {
  description = "AKS cluster name. Also used as the DNS prefix."
  type        = string
  default     = "spring-demo-aks"
}

variable "node_min_count" {
  description = <<-EOT
    Floor for the cluster autoscaler, and the size the cluster starts at.

    Cannot be 0 for a cluster's only node pool - something has to run the system
    pods (CoreDNS, kube-proxy, metrics-server). So this is your standing cost:
    one node, always on, whether or not anyone is using the app.
  EOT
  type    = number
  default = 1
}

variable "node_max_count" {
  description = <<-EOT
    Ceiling for the cluster autoscaler. This is your real cost cap - the HPA's
    maxReplicas caps pods, but pods are free; nodes are what you pay for.

    At 3 nodes of Standard_D2as_v7 you are looking at roughly triple the
    baseline. Keep it low while learning.
  EOT
  type    = number
  default = 3
}

variable "node_vm_size" {
  description = <<-EOT
    Node VM size. This is the single biggest line on your bill.

    Standard_D2as_v7 was picked from the list your subscription actually allows -
    the tutorial's Standard_D4lds_v5 is blocked for this subscription in eastus.

    Do NOT switch to a size with a "p" in it (Standard_B2pls_v2 and friends).
    Those are ARM64. Your image is built for amd64 and pods would crash-loop
    with "exec format error", which is a genuinely confusing failure to debug.
  EOT
  type        = string
  default     = "Standard_D2as_v7"
}

variable "tags" {
  description = "Tags applied to the cluster."
  type        = map(string)
  default = {
    project    = "aks-spring-demo"
    managed_by = "terraform"
    lifecycle  = "disposable"
  }
}
