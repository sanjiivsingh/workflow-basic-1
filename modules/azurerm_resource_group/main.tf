resource "azurerm_resource_group" "this" {
  for_each = var.config
  name     = each.value.name
  location = each.value.location
  tags     = each.value.tags
}


