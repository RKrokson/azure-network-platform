resource "azurerm_virtual_wan" "vwan" {
  name                = "${var.azurerm_virtual_wan_name}-${local.suffix}"
  resource_group_name = local.rg00_name
  location            = local.rg00_location
  tags                = local.common_tags
}
