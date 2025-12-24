# =============================================================================
# Terraform Configuration
# =============================================================================

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}


provider "azurerm" {
  features {}
}

provider "aws" {
  region = var.aws_region
}

# =============================================================================
# AZURE RESOURCES
# =============================================================================

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = "${var.project_name}-rg"
  location = var.azure_location
}

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "azure-vpn-vnet"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [var.azure_vnet_cidr]
}

# Gateway Subnet (must be named "GatewaySubnet")
resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.azure_gateway_subnet_cidr]
}

# Workload Subnet
resource "azurerm_subnet" "workload" {
  name                 = "workload-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.azure_workload_subnet_cidr]
}

# Public IP for VPN Gateway
resource "azurerm_public_ip" "vpn_gateway" {
  name                = "azure-vpn-gateway-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1", "2", "3"]
}

# VPN Gateway (takes 45+ minutes to deploy)
resource "azurerm_virtual_network_gateway" "main" {
  name                = "azure-vpn-gateway"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = "VpnGw1AZ"
  generation          = "Generation1"
  active_active       = false
  enable_bgp          = false

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn_gateway.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }
}

# Local Network Gateway (represents AWS)
resource "azurerm_local_network_gateway" "aws" {
  name                = "aws-local-gateway"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  gateway_address     = aws_vpn_connection.main.tunnel1_address
  address_space       = [var.aws_vpc_cidr]
}

# VPN Connection to AWS
resource "azurerm_virtual_network_gateway_connection" "aws" {
  name                       = "azure-to-aws-connection"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.main.id
  local_network_gateway_id   = azurerm_local_network_gateway.aws.id
  shared_key                 = var.shared_key

  # IKEv2 settings
  connection_protocol = "IKEv2"
}

# Network Security Group
resource "azurerm_network_security_group" "main" {
  name                = "vpn-test-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # Allow ICMP from AWS
  security_rule {
    name                       = "Allow-AWS-ICMP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = var.aws_vpc_cidr
    destination_address_prefix = "*"
  }

  # Allow SSH from AWS
  security_rule {
    name                       = "Allow-AWS-SSH"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.aws_vpc_cidr
    destination_address_prefix = "*"
  }

  # Allow SSH from your IPs
  security_rule {
    name                       = "Allow-MyIP-SSH"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = var.my_ip_addresses
    destination_address_prefix = "*"
  }
}

# Associate NSG with Workload Subnet
resource "azurerm_subnet_network_security_group_association" "workload" {
  subnet_id                 = azurerm_subnet.workload.id
  network_security_group_id = azurerm_network_security_group.main.id
}

# Azure VM NIC
resource "azurerm_network_interface" "vm" {
  name                = "vpn-test-vm-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.workload.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.vm.id
  }
}

# Public IP for Azure VM
resource "azurerm_public_ip" "vm" {
  name                = "vpn-test-vm-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Azure VM
resource "azurerm_linux_virtual_machine" "main" {
  name                            = "vpn-test-vm"
  location                        = azurerm_resource_group.main.location
  resource_group_name             = azurerm_resource_group.main.name
  size                            = "Standard_B1s"
  admin_username                  = var.azure_vm_admin_username
  admin_password                  = var.azure_vm_admin_password
  disable_password_authentication = false
  network_interface_ids           = [azurerm_network_interface.vm.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

# =============================================================================
# AWS RESOURCES
# =============================================================================

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.aws_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "aws-azure-vpn-vpc"
  }
}

# Private Subnet
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.aws_private_subnet_cidr
  availability_zone       = var.aws_availability_zone
  map_public_ip_on_launch = true

  tags = {
    Name = "private-subnet"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "aws-azure-vpn-igw"
  }
}

# Virtual Private Gateway
resource "aws_vpn_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "aws-azure-vpn-vgw"
  }
}

# Customer Gateway (represents Azure VPN Gateway)
resource "aws_customer_gateway" "azure" {
  bgp_asn    = 65515
  ip_address = azurerm_public_ip.vpn_gateway.ip_address
  type       = "ipsec.1"

  tags = {
    Name = "azure-vpn-gateway-cgw"
  }

  depends_on = [azurerm_virtual_network_gateway.main]
}

# VPN Connection
resource "aws_vpn_connection" "main" {
  vpn_gateway_id      = aws_vpn_gateway.main.id
  customer_gateway_id = aws_customer_gateway.azure.id
  type                = "ipsec.1"
  static_routes_only  = true

  tunnel1_preshared_key = var.shared_key
  tunnel2_preshared_key = var.shared_key

  tags = {
    Name = "azure-vpn-connection"
  }
}

# VPN Connection Route
resource "aws_vpn_connection_route" "azure" {
  destination_cidr_block = var.azure_vnet_cidr
  vpn_connection_id      = aws_vpn_connection.main.id
}

# Route Table
resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  # Route to Internet
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  # Route to Azure via VPN Gateway
  route {
    cidr_block = var.azure_vnet_cidr
    gateway_id = aws_vpn_gateway.main.id
  }

  tags = {
    Name = "aws-azure-vpn-rt"
  }
}

# Route Table Association
resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.main.id
}

# Enable VGW Route Propagation
resource "aws_vpn_gateway_route_propagation" "main" {
  vpn_gateway_id = aws_vpn_gateway.main.id
  route_table_id = aws_route_table.main.id
}

# Security Group
resource "aws_security_group" "main" {
  name        = "vpn-test-sg"
  description = "Allow traffic for VPN testing"
  vpc_id      = aws_vpc.main.id

  # Allow ICMP from Azure
  ingress {
    description = "ICMP from Azure"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.azure_vnet_cidr]
  }

  # Allow SSH from Azure
  ingress {
    description = "SSH from Azure"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.azure_vnet_cidr]
  }

  # Allow SSH from your IPs
  ingress {
    description = "SSH for setup"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.my_ip_addresses
  }

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vpn-test-sg"
  }
}

# Key Pair for EC2
resource "aws_key_pair" "main" {
  key_name   = "vpn-test-key"
  public_key = tls_private_key.main.public_key_openssh
}

# Generate SSH Key
resource "tls_private_key" "main" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save private key locally
resource "local_file" "private_key" {
  content         = tls_private_key.main.private_key_pem
  filename        = "${path.module}/vpn-test-key.pem"
  file_permission = "0400"
}

# Get latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 Instance
resource "aws_instance" "main" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.main.id]
  key_name                    = aws_key_pair.main.key_name
  associate_public_ip_address = true

  tags = {
    Name = "vpn-test-ec2"
  }
}