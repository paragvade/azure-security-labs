output "firewall_vm_public_ip" {
  description = "Public IP of the firewall VM"
  value       = azurerm_public_ip.fw_pip.ip_address
}

output "vm_a_public_ip" {
  description = "Public IP of workload VM A"
  value       = azurerm_public_ip.vm_a_pip.ip_address
}

output "vm_b_public_ip" {
  description = "Public IP of workload VM B"
  value       = azurerm_public_ip.vm_b_pip.ip_address
}

output "firewall_private_ip" {
  description = "Private IP of the firewall VM NIC (used as UDR next hop)"
  value       = azurerm_network_interface.fw_nic.ip_configuration[0].private_ip_address
}
