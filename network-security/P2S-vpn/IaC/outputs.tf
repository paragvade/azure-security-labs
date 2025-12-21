# iac/outputs.tf
output "webvm_private_ip" {
  description = "Private IP of the web server VM"
  value       = azurerm_windows_virtual_machine.webvm.private_ip_address
}

output "webvm_public_ip" {
  description = "Public IP of the web server VM (remove after testing)"
  value       = azurerm_public_ip.webvm_public_ip.ip_address
}

output "webvm_rdp_connection" {
  description = "RDP connection details"
  value       = "RDP to ${azurerm_public_ip.webvm_public_ip.ip_address} as appadmin/abcd1234"
}

output "vpn_gateway_public_ip" {
  description = "Public IP of VPN Gateway"
  value       = azurerm_public_ip.gateway_public_ip.ip_address
}

output "vpn_gateway_id" {
  description = "ID of VPN Gateway for certificate upload"
  value       = azurerm_virtual_network_gateway.app_gateway.id
}

output "vnet_id" {
  description = "VNet ID - appears in VPN client"
  value       = azurerm_virtual_network.app_vnet.id
}
