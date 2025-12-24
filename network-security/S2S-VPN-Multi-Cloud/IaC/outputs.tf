# =============================================================================
# Azure Outputs
# =============================================================================

output "azure_resource_group" {
  description = "Azure Resource Group name"
  value       = azurerm_resource_group.main.name
}

output "azure_vnet_name" {
  description = "Azure VNet name"
  value       = azurerm_virtual_network.main.name
}

output "azure_vpn_gateway_public_ip" {
  description = "Azure VPN Gateway Public IP"
  value       = azurerm_public_ip.vpn_gateway.ip_address
}

output "azure_vm_private_ip" {
  description = "Azure VM Private IP"
  value       = azurerm_network_interface.vm.private_ip_address
}

output "azure_vm_public_ip" {
  description = "Azure VM Public IP (for SSH)"
  value       = azurerm_public_ip.vm.ip_address
}

output "azure_connection_status" {
  description = "Azure VPN Connection name"
  value       = azurerm_virtual_network_gateway_connection.aws.name
}

# =============================================================================
# AWS Outputs
# =============================================================================

output "aws_vpc_id" {
  description = "AWS VPC ID"
  value       = aws_vpc.main.id
}

output "aws_vpn_connection_id" {
  description = "AWS VPN Connection ID"
  value       = aws_vpn_connection.main.id
}

output "aws_tunnel1_address" {
  description = "AWS VPN Tunnel 1 Outside IP"
  value       = aws_vpn_connection.main.tunnel1_address
}

output "aws_tunnel2_address" {
  description = "AWS VPN Tunnel 2 Outside IP"
  value       = aws_vpn_connection.main.tunnel2_address
}

output "aws_ec2_private_ip" {
  description = "AWS EC2 Private IP"
  value       = aws_instance.main.private_ip
}

output "aws_ec2_public_ip" {
  description = "AWS EC2 Public IP (for SSH)"
  value       = aws_instance.main.public_ip
}

# =============================================================================
# Connection Test Commands
# =============================================================================

output "test_commands" {
  description = "Commands to test VPN connectivity"
  value       = <<-EOT
    
    ============================================
    TEST CONNECTIVITY
    ============================================
    
    1. SSH into Azure VM:
       ssh ${var.azure_vm_admin_username}@${azurerm_public_ip.vm.ip_address}
    
    2. From Azure VM, ping AWS EC2:
       ping ${aws_instance.main.private_ip} -c 5
    
    3. SSH into AWS EC2:
       ssh -i vpn-test-key.pem ec2-user@${aws_instance.main.public_ip}
    
    4. From AWS EC2, ping Azure VM:
       ping ${azurerm_network_interface.vm.private_ip_address} -c 5
    
    ============================================
  EOT
}

# =============================================================================
# Cleanup Command
# =============================================================================

output "cleanup_command" {
  description = "Command to destroy all resources"
  value       = "terraform destroy -auto-approve"
}