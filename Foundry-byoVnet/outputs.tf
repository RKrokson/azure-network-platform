output "foundry_regions" {
  description = "Deployed Foundry stacks keyed by alz_regions key. region1 is present only when it was deployed."
  value       = { for key, stack in module.foundry_region : key => stack.foundry_region }
}
