variable "rg_name" {
  description = "The name of an existing resource group to be imported."
  type = string
}

variable "location" {
  description = "The Azure Region."
  type = string
}

variable "name" {
  description = "Name of firewall policy."
  type = string
}

variable "sku" {
  description = "SKU of the Firewall. Possible values are Premium or Standard."
  type = string
  default = "Standard"
}

variable "rules_base_folder" {
  description = ""
  type = string
  default = null
}

variable "rule_collections" {
  type = list
  default = []
}

variable "enable_dns_proxy" {
  type = bool
  default = false
}
