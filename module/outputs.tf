output "policy_id" {
  description = "Resource Id of firewall policy instance."
  value = azurerm_firewall_policy.policy.id
}

output "rules" {
  value = azurerm_firewall_policy_rule_collection_group.group_yaml
}
