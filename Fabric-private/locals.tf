locals {
  common_tags = {
    environment = "non-prod"
    managed_by  = "terraform"
    project     = "azure-infra-poc"
  }

  # Capacity admin resolution: group OID > explicit UPN list > current user fallback
  capacity_admins = (
    var.capacity_admin_group_object_id != null
    ? [var.capacity_admin_group_object_id]
    : (
      length(var.capacity_admin_upn_list) > 0
      ? var.capacity_admin_upn_list
      : [data.external.current_user_upn[0].result.upn]
    )
  )

  # network_mode decomposition — used to gate inbound and outbound resources independently
  deploy_inbound  = contains(["inbound_only", "inbound_and_outbound"], var.network_mode)
  deploy_outbound = contains(["outbound_only", "inbound_and_outbound"], var.network_mode)
}
