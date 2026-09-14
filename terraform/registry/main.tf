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

# ---------------------------------------------------------------------------
# The identity GitHub Actions logs in as.
#
# Previously this was an Entra app registration created by hand with
# `az ad app create`. The KMS tenant sets allowedToCreateApps = false, so that
# route is closed - a normal user cannot write objects into the directory.
#
# A user-assigned managed identity gets to the same place by a different road.
# It is an Azure RESOURCE, not a directory object, so creating it needs only
# Contributor on a resource group. The service principal behind it is created
# by the ManagedIdentity resource provider on your behalf, which is what makes
# it work in a tenant that will not let you create applications yourself.
#
# It is also the better design. The pipeline's identity is now code: readable
# in the repo, recreated identically by `terraform apply`, and destroyed with
# everything else - rather than a thing clicked once and half-remembered.
#
# Note this lives in the LONG-LIVED module. Destroying the cluster must not
# destroy the identity, or you would be re-doing GitHub secrets every session.
# ---------------------------------------------------------------------------
resource "azurerm_user_assigned_identity" "github" {
  name                = "github-actions"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  tags = var.tags
}

# ---------------------------------------------------------------------------
# The trust rule: "GitHub may act as that identity, from this repo only."
#
# Same three claims Azure checks as before - issuer, subject, audience - just
# attached to a managed identity instead of an app registration. No secret is
# created or stored anywhere. GitHub mints a short-lived signed token per run,
# and Azure verifies it against this rule.
#
# Two credentials, because the subject must match EXACTLY and GitHub's format
# depends on repo age and settings. The immutable form is what your repo
# currently sends; the legacy form is the older style. Extra rules that never
# match are harmless - Azure just needs one of them to.
# ---------------------------------------------------------------------------
resource "azurerm_federated_identity_credential" "github_main" {
  name                      = "github-main"
  user_assigned_identity_id = azurerm_user_assigned_identity.github.id
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = var.github_repository_subject
  audience                  = ["api://AzureADTokenExchange"]
}

resource "azurerm_federated_identity_credential" "github_main_legacy" {
  name                      = "github-main-legacy"
  user_assigned_identity_id = azurerm_user_assigned_identity.github.id
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = "repo:trananhvi/aks-spring-demo:ref:refs/heads/main"
  audience                  = ["api://AzureADTokenExchange"]
}

# ---------------------------------------------------------------------------
# What the pipeline is allowed to do: push images. That is all.
#
# Worth comparing to the old setup, which held Contributor AND Role Based
# Access Control Administrator across the entire subscription - enough to
# create or delete anything, and to grant itself more. It needed that because
# the plan at the time was for CI to run Terraform.
#
# Terraform runs locally as you instead, so the pipeline needs far less:
# AcrPush here, and cluster-user access on the AKS cluster (granted in
# terraform/cluster, since the cluster does not exist yet at this point).
#
# AcrPush includes pull. There is a separate AcrPull role, which is what the
# CLUSTER gets - it only ever reads.
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "github_acr_push" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPush"
  principal_id         = azurerm_user_assigned_identity.github.principal_id

  # The identity is seconds old here and Entra takes a moment to replicate it.
  # Without this, apply intermittently fails claiming the principal is unknown.
  skip_service_principal_aad_check = true
}
