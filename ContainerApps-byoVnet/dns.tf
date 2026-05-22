########## Private DNS for ACA Environment Domain
##########

# ACA internal environments generate a unique domain.
# Create a private DNS zone matching that domain so internal clients can resolve apps.
resource "azurerm_private_dns_zone" "aca_env_dns" {
  name                = azurerm_container_app_environment.aca_env.default_domain
  resource_group_name = azurerm_resource_group.rg_aca00.name
  tags                = local.common_tags
}

# Wildcard A record pointing all app names to the ACA environment static IP
resource "azurerm_private_dns_a_record" "aca_wildcard" {
  name                = "*"
  zone_name           = azurerm_private_dns_zone.aca_env_dns.name
  resource_group_name = azurerm_resource_group.rg_aca00.name
  ttl                 = 300
  records             = [azurerm_container_app_environment.aca_env.static_ip_address]
}

# Link ACA environment DNS zone to ACA VNet
resource "azurerm_private_dns_zone_virtual_network_link" "aca_env_dns_aca_vnet_link" {
  name                  = "aca-env-dns-to-aca-vnet-${random_string.unique.result}"
  resource_group_name   = azurerm_resource_group.rg_aca00.name
  private_dns_zone_name = azurerm_private_dns_zone.aca_env_dns.name
  virtual_network_id    = azurerm_virtual_network.aca_vnet.id
  tags                  = local.common_tags
}

# Link ACA environment DNS zone to DNS VNet for centralized resolution
resource "azurerm_private_dns_zone_virtual_network_link" "aca_env_dns_platform_vnet_link" {
  name                  = "aca-env-dns-to-dns-vnet-${random_string.unique.result}"
  resource_group_name   = azurerm_resource_group.rg_aca00.name
  private_dns_zone_name = azurerm_private_dns_zone.aca_env_dns.name
  virtual_network_id    = data.terraform_remote_state.networking.outputs.dns_vnet00_id
  tags                  = local.common_tags
}
