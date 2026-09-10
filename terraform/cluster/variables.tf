# ---------------------------------------------------------------------------
# Input variables.
#
# resource_group_name and acr_name must match the values in
# terraform/registry/variables.tf - this module looks those resources up by name.
# ---------------------------------------------------------------------------

variable "subscription_id" {
  description = "Azure subscription to build in. KMS Technology tenant, free trial."
  type        = string
  default     = "e9d8503a-0aae-40c2-a82e-eca5676787d3"
}

variable "github_identity_name" {
  description = "Managed identity created by terraform/registry. Must match its output."
  type        = string
  default     = "github-actions"
}

variable "resource_group_name" {
  description = "Existing resource group created by terraform/registry."
  type        = string
  default     = "aks-spring-demo"
}

variable "acr_name" {
  description = "Existing container registry created by terraform/registry. Must match its acr_name."
  type        = string
  default     = "quayvitrankms"
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

    Set to 2, not 3, because this runs on an Azure free trial subscription.
    Those carry a low regional vCPU quota - commonly 4 total. At 2 vCPU per
    node, 3 nodes would need 6 and the autoscaler would fail partway through a
    scale-up with a quota error, which reads as a confusing Kubernetes problem
    rather than the billing limit it actually is.

    On a pay-as-you-go subscription this can go higher.
  EOT
  type    = number
  default = 2
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
