terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>5.0.1"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rgforstate"
    storage_account_name = "astorageforstate"
    container_name       = "containerforstate"
    key                  = "rgstatefile.tfstate"
  }
}

provider "azurerm" {
  features {}
}