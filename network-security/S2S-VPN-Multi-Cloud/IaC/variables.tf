# =============================================================================
# Common Variables
# =============================================================================

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "azure-aws-vpn"
}

variable "shared_key" {
  description = "Pre-shared key for VPN connection (A-Z, a-z, 0-9, _ and . only)"
  type        = string
  default     = "AzureAws2025VpnLab_SecureKey"
  sensitive   = true
}

# =============================================================================
# Azure Variables
# =============================================================================

variable "azure_location" {
  description = "Azure region"
  type        = string
  default     = "East US"
}

variable "azure_vnet_cidr" {
  description = "Azure VNet CIDR"
  type        = string
  default     = "10.1.0.0/16"
}

variable "azure_gateway_subnet_cidr" {
  description = "Azure Gateway Subnet CIDR"
  type        = string
  default     = "10.1.255.0/27"
}

variable "azure_workload_subnet_cidr" {
  description = "Azure Workload Subnet CIDR"
  type        = string
  default     = "10.1.1.0/24"
}

variable "azure_vm_admin_username" {
  description = "Azure VM admin username"
  type        = string
  default     = "azureuser"
}

variable "azure_vm_admin_password" {
  description = "Azure VM admin password"
  type        = string
  sensitive   = true
}

# =============================================================================
# AWS Variables
# =============================================================================

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_vpc_cidr" {
  description = "AWS VPC CIDR"
  type        = string
  default     = "10.2.0.0/16"
}

variable "aws_private_subnet_cidr" {
  description = "AWS Private Subnet CIDR"
  type        = string
  default     = "10.2.1.0/24"
}

variable "aws_availability_zone" {
  description = "AWS Availability Zone"
  type        = string
  default     = "us-east-1a"
}

variable "my_ip_addresses" {
  description = "Your public IP addresses for SSH access (CIDR format)"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Replace with your IPs for security
}