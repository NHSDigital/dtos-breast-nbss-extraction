terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.59.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "3.4.0"
    }
  }
  backend "azurerm" {
    container_name       = "terraform-state"
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.arm_subscription_id
}

provider "azurerm" {
  features {}

  alias           = "hub"
  subscription_id = var.hub_subscription_id

}

provider "azuread" {}
