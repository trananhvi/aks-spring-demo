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

    Kept as "quayvitran" so it matches docker.image.prefix in complete/pom.xml,
    which means local `mvn jib:build` runs keep working without extra flags.

    If apply fails because the name is taken - a deleted registry name can stay
    reserved for a while - change it here AND in complete/pom.xml line 19.
  EOT
  type        = string
  default     = "quayvitran"

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
