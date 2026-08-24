# ---------------------------------------------------------------------------
# Long-lived infrastructure: a resource group and a container registry.
#
# This directory is a Terraform "root module" - a self-contained unit with its
# own state file. terraform/cluster/ is a second, separate root module.
#
# That split is the whole point of the layout. You can run `terraform destroy`
# in cluster/ to stop paying for the node VM, and everything here - including
# every image you have pushed - survives untouched.
# ---------------------------------------------------------------------------

terraform {
  # The version of Terraform itself.
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"

      # "~> 4.0" means any 4.x release, but never 5.0. Provider major versions
      # make breaking changes, so pinning the major version is standard practice.
      # The exact version actually chosen gets recorded in .terraform.lock.hcl,
      # which is committed so every machine resolves identically.
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  # Required even when empty. This block is where you opt into provider-wide
  # behaviours - for example, whether destroying a Key Vault also purges it.
  features {}

  # Version 4 of the provider requires this explicitly; earlier versions
  # inferred it from whatever `az account show` returned. Being explicit is
  # better anyway: a config that silently follows your CLI's current
  # subscription is a config that can build things in the wrong place.
  subscription_id = var.subscription_id
}

# ---------------------------------------------------------------------------
# The resource group.
#
# Equivalent to the `az group create` you ran by hand. Note what is NOT here:
# no `az provider register --namespace Microsoft.ContainerRegistry`. The
# provider registers namespaces on your behalf, so the MissingSubscriptionRegistration
# error you hit manually cannot happen through Terraform.
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = var.tags
}

# ---------------------------------------------------------------------------
# The container registry - `az acr create --sku Basic`.
#
# Look at resource_group_name below. It does not say "aks-spring-demo"; it
# reads the name back off the resource group resource. That reference is what
# tells Terraform the registry depends on the group, so the group is created
# first and destroyed last. You never write ordering by hand - Terraform
# derives the whole graph from references like this one.
#
# admin_enabled = false disables the registry's built-in username/password.
# Nothing needs it: your workflow authenticates with Entra via OIDC, and the
# cluster will authenticate with its own managed identity.
# ---------------------------------------------------------------------------
resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Basic"
  admin_enabled       = false

  tags = var.tags
}
