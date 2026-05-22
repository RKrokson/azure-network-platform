output "vm_admin_username" {
  description = "Virtual Machine Admin Username"
  value       = module.region0.vm_admin_username
  sensitive   = true
}
output "rg_net00_id" {
  description = "The ID of the Networking Resource Group."
  value       = azurerm_resource_group.rg-net00.id
}
output "rg_net00_location" {
  description = "The location of the Networking Resource Group."
  value       = local.rg00_location
}
output "azure_region_0_abbr" {
  description = "The abbreviation of the Azure 0 region."
  value       = var.azure_region_0_abbr
}
# vHub outputs
output "vhub00_id" {
  description = "The ID of Virtual Hub 00"
  value       = module.region0.hub_id
}
output "vhub01_id" {
  description = "The ID of Virtual Hub 01"
  value       = var.create_vhub01 ? module.region1[0].hub_id : null
}

# Log Analytics Workspace
output "log_analytics_workspace_id" {
  description = "The ID of the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.law00.id
}

# Key Vault
output "key_vault_id" {
  description = "The ID of Key Vault"
  value       = azurerm_key_vault.kv00.id
}
output "key_vault_name" {
  description = "The name of Key Vault"
  value       = azurerm_key_vault.kv00.name
}

# Private DNS Zone IDs (constructed from the RG that hosts them)
output "dns_zone_blob_id" {
  description = "Private DNS Zone ID for privatelink.blob.core.windows.net"
  value       = var.add_private_dns00 ? "${azurerm_resource_group.rg-net00.id}/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net" : null
}
output "dns_zone_file_id" {
  description = "Private DNS Zone ID for privatelink.file.core.windows.net"
  value       = var.add_private_dns00 ? "${azurerm_resource_group.rg-net00.id}/providers/Microsoft.Network/privateDnsZones/privatelink.file.core.windows.net" : null
}
output "dns_zone_table_id" {
  description = "Private DNS Zone ID for privatelink.table.core.windows.net"
  value       = var.add_private_dns00 ? "${azurerm_resource_group.rg-net00.id}/providers/Microsoft.Network/privateDnsZones/privatelink.table.core.windows.net" : null
}
output "dns_zone_queue_id" {
  description = "Private DNS Zone ID for privatelink.queue.core.windows.net"
  value       = var.add_private_dns00 ? "${azurerm_resource_group.rg-net00.id}/providers/Microsoft.Network/privateDnsZones/privatelink.queue.core.windows.net" : null
}
output "dns_zone_vaultcore_id" {
  description = "Private DNS Zone ID for privatelink.vaultcore.azure.net"
  value       = var.add_private_dns00 ? "${azurerm_resource_group.rg-net00.id}/providers/Microsoft.Network/privateDnsZones/privatelink.vaultcore.azure.net" : null
}
output "dns_zone_cognitiveservices_id" {
  description = "Private DNS Zone ID for privatelink.cognitiveservices.azure.com"
  value       = var.add_private_dns00 ? "${azurerm_resource_group.rg-net00.id}/providers/Microsoft.Network/privateDnsZones/privatelink.cognitiveservices.azure.com" : null
}
output "dns_zone_openai_id" {
  description = "Private DNS Zone ID for privatelink.openai.azure.com"
  value       = var.add_private_dns00 ? "${azurerm_resource_group.rg-net00.id}/providers/Microsoft.Network/privateDnsZones/privatelink.openai.azure.com" : null
}
output "dns_zone_services_ai_id" {
  description = "Private DNS Zone ID for privatelink.services.ai.azure.com"
  value       = var.add_private_dns00 ? "${azurerm_resource_group.rg-net00.id}/providers/Microsoft.Network/privateDnsZones/privatelink.services.ai.azure.com" : null
}
output "dns_zone_search_id" {
  description = "Private DNS Zone ID for privatelink.search.windows.net"
  value       = var.add_private_dns00 ? "${azurerm_resource_group.rg-net00.id}/providers/Microsoft.Network/privateDnsZones/privatelink.search.windows.net" : null
}
output "dns_zone_documents_id" {
  description = "Private DNS Zone ID for privatelink.documents.azure.com"
  value       = var.add_private_dns00 ? "${azurerm_resource_group.rg-net00.id}/providers/Microsoft.Network/privateDnsZones/privatelink.documents.azure.com" : null
}
output "dns_zone_acr_id" {
  description = "Private DNS Zone ID for privatelink.azurecr.io"
  value       = var.add_private_dns00 ? "${azurerm_resource_group.rg-net00.id}/providers/Microsoft.Network/privateDnsZones/privatelink.azurecr.io" : null
}
output "dns_zone_fabric_id" {
  description = "Private DNS Zone ID for privatelink.fabric.microsoft.com"
  value       = var.add_private_dns00 ? "${azurerm_resource_group.rg-net00.id}/providers/Microsoft.Network/privateDnsZones/privatelink.fabric.microsoft.com" : null
}
output "dns_zone_sql_id" {
  description = "Private DNS Zone ID for privatelink.database.windows.net"
  value       = var.add_private_dns00 ? "${azurerm_resource_group.rg-net00.id}/providers/Microsoft.Network/privateDnsZones/privatelink.database.windows.net" : null
}

# Platform outputs consumed by application landing zones
output "rg_net00_name" {
  description = "The name of the Networking Resource Group for region 0"
  value       = azurerm_resource_group.rg-net00.name
}
output "add_firewall00" {
  description = "Whether Azure Firewall is deployed in region 0 (controls internet_security_enabled on hub connections)"
  value       = var.add_firewall00
}
output "dns_resolver_policy00_id" {
  description = "The ID of the DNS resolver policy for region 0 (null if Private DNS is not deployed)"
  value       = module.region0.dns_resolver_policy_id
}
output "dns_inbound_endpoint00_ip" {
  description = "The IP address of the DNS resolver inbound endpoint for region 0 (null if Private DNS is not deployed)"
  value       = module.region0.dns_inbound_endpoint_ip
}
output "firewall_private_ip00" {
  description = "The private IP of the Azure Firewall in region 0 (null if firewall is not deployed)"
  value       = module.region0.firewall_private_ip
}
output "dns_vnet00_id" {
  description = "The ID of the DNS VNet in region 0 (null if Private DNS is not deployed)"
  value       = module.region0.dns_vnet_id
}
output "dns_server_ip00" {
  description = "The DNS server IP for spoke VNets in region 0 — firewall IP when deployed (DNS proxy), otherwise DNS resolver inbound endpoint IP"
  value       = var.add_firewall00 ? module.region0.firewall_private_ip : module.region0.dns_inbound_endpoint_ip
}