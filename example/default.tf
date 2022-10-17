terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}
}

module "fwpolicy" {
  source = "../module"

  rg_name = "rg"
  location = "westeurope"
  name = "azfw-policy"
  rules_base_folder = "./firewall/"
  # folders to process and apply to policy
  rule_collections = [ 
    "group01"
  ]
}
