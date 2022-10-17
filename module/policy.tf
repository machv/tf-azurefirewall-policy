resource "azurerm_firewall_policy" "policy" {
  name = "${var.name}"
  resource_group_name = var.rg_name
  location = var.location
  sku = var.sku

  dns {
    proxy_enabled = var.enable_dns_proxy
  }
}

resource "azurerm_firewall_policy_rule_collection_group" "group_yaml" {
  for_each = toset(var.rule_collections)
  
  firewall_policy_id = azurerm_firewall_policy.policy.id
  name = yamldecode(file("${var.rules_base_folder}/${each.value}/collection.yaml")).name
  priority = yamldecode(file("${var.rules_base_folder}/${each.value}/collection.yaml")).priority

  dynamic "network_rule_collection" {
    for_each = fileset("${var.rules_base_folder}/${each.value}/", "network_*.yaml")

    content {
      name = yamldecode(file("${var.rules_base_folder}/${each.value}/${network_rule_collection.value}")).name
      priority = yamldecode(file("${var.rules_base_folder}/${each.value}/${network_rule_collection.value}")).priority
      action = yamldecode(file("${var.rules_base_folder}/${each.value}/${network_rule_collection.value}")).action

      dynamic "rule" {
        for_each = yamldecode(file("${var.rules_base_folder}/${each.value}/${network_rule_collection.value}")).rules
        //for_each = {
        //  for rule in yamldecode(file("${var.rules_base_folder}/${each.value}/${network_rule_collection.value}")).rules : rule.name => rule
        //}
        
        content {
          name = rule.value.name
          source_addresses = try(
            [tostring(rule.value.source_addresses)],
            tolist(rule.value.source_addresses),
          )
          source_ip_groups = try(
            [tostring(rule.value.source_ip_groups)],
            tolist(rule.value.source_ip_groups),
            [],
          )
          destination_addresses = try(
            [tostring(rule.value.destination_addresses)],
            tolist(rule.value.destination_addresses),
            [],
          )
          destination_fqdns = try(
            [tostring(rule.value.destination_fqdns)],
            tolist(rule.value.destination_fqdns),
            [],
          )
          destination_ip_groups = try(
            [tostring(rule.value.destination_ip_groups)],
            tolist(rule.value.destination_ip_groups),
            [],
          )
          destination_ports = try(
            [tostring(rule.value.destination_ports)],
            tolist(rule.value.destination_ports),
          )
          protocols = try(
            [tostring(rule.value.protocols)],
            tolist(rule.value.protocols),
          )
        }
      }
    }
  }

  dynamic "application_rule_collection" {
    for_each = fileset("${var.rules_base_folder}/${each.value}/", "application_*.yaml")

    content {
      name = yamldecode(file("${var.rules_base_folder}/${each.value}/${application_rule_collection.value}")).name
      priority = yamldecode(file("${var.rules_base_folder}/${each.value}/${application_rule_collection.value}")).priority
      action = yamldecode(file("${var.rules_base_folder}/${each.value}/${application_rule_collection.value}")).action

      dynamic "rule" {
        //for_each = yamldecode(file("${var.rules_base_folder}/${each.value}/${application_rule_collection.value}")).rules
        for_each = {
          for rule in yamldecode(file("${var.rules_base_folder}/${each.value}/${application_rule_collection.value}")).rules : rule.name => rule
        }

        content {
          name = rule.value.name
          description = try(rule.value.description, null)
          source_addresses = try(
            [tostring(rule.value.source_addresses)],
            tolist(rule.value.source_addresses),
            [],
          )
          source_ip_groups = try(
            [tostring(rule.value.source_ip_groups)],
            tolist(rule.value.source_ip_groups),
            [],
          )
          destination_addresses = try(
            [tostring(rule.value.destination_addresses)],
            tolist(rule.value.destination_addresses),
            [],
          )
          destination_fqdns = try(
            [tostring(rule.value.destination_fqdns)],
            tolist(rule.value.destination_fqdns),
            [],
          )
          destination_fqdn_tags = try(
            [tostring(rule.value.destination_fqdn_tags)],
            tolist(rule.value.destination_fqdn_tags),
            [],
          )

          dynamic "protocols" {
            for_each = rule.value.protocols

            content {
              type = protocols.value.type
              port = protocols.value.port
            }
          }
        }
      }
    }
  }

/*
        for_each = {
          for rule in yamldecode(file("${var.rules_base_folder}/${each.value}/${network_rule_collection.value}")).rules : rule.name => rule
        }
  nat_rule_collection {
    name     = "nat_rule_collection1"
    priority = 300
    action   = "Dnat"
    rule {
      name                = "nat_rule_collection1_rule1"
      protocols           = ["TCP", "UDP"]
      source_addresses    = ["10.0.0.1", "10.0.0.2"]
      destination_address = "192.168.1.1"
      destination_ports   = ["80", "1000-2000"]
      translated_address  = "192.168.0.1"
      translated_port     = "8080"
    }
  }
*/
}
