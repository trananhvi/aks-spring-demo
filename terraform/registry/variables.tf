# ---------------------------------------------------------------------------
# Input variables.
#
# Every variable here has a default, so `terraform apply` works with no
# arguments. Override one on the command line with -var, or put overrides in a
# terraform.tfvars file, which Terraform loads automatically.
# ---------------------------------------------------------------------------

variable "subscription_id" {
  description = "Azure subscription to build in."
  type        = string
  default     = "09edd562-ff99-4aa1-a4c6-a093ce9d79b2"
}

variable "resource_group_name" {
  description = "Resource group holding the registry. Kept separate from the cluster's lifecycle."
  type        = string
  default     = "aks-spring-demo"
}

variable "location" {
  description = "Azure region. eastus is where the VM sizes available to this subscription live."
  type        = string
  default     = "eastus"
}

variable "acr_name" {
  description = <<-EOT
    Container registry name. This becomes <name>.azurecr.io and must be globally
    unique across all of Azure, alphanumeric only, 5-50 characters.

    Matches docker.image.prefix in complete/pom.xml, so local `mvn jib:build`
    runs keep working without extra flags. Change both together.

    Renamed from "quayvitran" when the project moved to the KMS subscription.
    Azure can hold a recently deleted registry name in reserve, so reusing the
    old one straight after destroying it risks a name-unavailable error.
  EOT
  type        = string
  default     = "quayvitrankms"

  validation {
    condition     = can(regex("^[a-zA-Z0-9]{5,50}$", var.acr_name))
    error_message = "ACR names must be 5-50 characters, letters and digits only - no hyphens or underscores."
  }
}

variable "tags" {
  description = "Tags applied to everything here. Useful for spotting stray resources on your bill."
  type        = map(string)
  default = {
    project     = "aks-spring-demo"
    managed_by  = "terraform"
    lifecycle   = "long-lived"
  }
}
