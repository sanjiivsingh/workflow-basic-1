module "resource_group" {
  source = "../../modules/azurerm_resource_group"
  config = var.resource_group
}