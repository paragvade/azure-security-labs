# iac/main.tf
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "6f85ad88-a97a-4324-b8be-fdfc7411f853"
 }

# Resource Group
resource "azurerm_resource_group" "app_rg" {
  name     = var.resource_group_name
  location = var.location
}

# Virtual Network
resource "azurerm_virtual_network" "app_vnet" {
  name                = "app-network"
  address_space       = [var.vnet_cidr]
  location            = azurerm_resource_group.app_rg.location
  resource_group_name = azurerm_resource_group.app_rg.name
}

# Web Subnet
resource "azurerm_subnet" "web_subnet" {
  name                 = "websubnet"
  resource_group_name  = azurerm_resource_group.app_rg.name
  virtual_network_name = azurerm_virtual_network.app_vnet.name
  address_prefixes     = [var.web_subnet_cidr]
}

# Gateway Subnet (Required for VPN Gateway)
resource "azurerm_subnet" "gateway_subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.app_rg.name
  virtual_network_name = azurerm_virtual_network.app_vnet.name
  address_prefixes     = [var.gateway_subnet_cidr]
}

# Public IP for Web VM (will be dissociated later)
resource "azurerm_public_ip" "webvm_public_ip" {
  name                = "webvm01-ip"
  location            = azurerm_resource_group.app_rg.location
  resource_group_name = azurerm_resource_group.app_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Network Security Group for RDP + HTTP
resource "azurerm_network_security_group" "webvm_nsg" {
  name                = "webvm01-nsg"
  location            = azurerm_resource_group.app_rg.location
  resource_group_name = azurerm_resource_group.app_rg.name

  security_rule {
    name                       = "RDP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Network Interface for Web VM
resource "azurerm_network_interface" "webvm_nic" {
  name                = "webvm01-nic"
  location            = azurerm_resource_group.app_rg.location
  resource_group_name = azurerm_resource_group.app_rg.name

  ip_configuration {
    name                          = "webvm-nic-ipconfig"
    subnet_id                     = azurerm_subnet.web_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.webvm_public_ip.id
  }
}

# Associate NSG to NIC
resource "azurerm_network_interface_security_group_association" "webvm_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.webvm_nic.id
  network_security_group_id = azurerm_network_security_group.webvm_nsg.id
}

# Windows Web Server VM - FIXED PASSWORD & custom_data
resource "azurerm_windows_virtual_machine" "webvm" {
  name                  = "webvm01"
  resource_group_name   = azurerm_resource_group.app_rg.name
  location              = azurerm_resource_group.app_rg.location
  size                  = "Standard_D2s_v3"
  admin_username        = "appadmin"
  admin_password        = "Abcd@1234"  # ✅ Lower+Upper+Digit+Special

  network_interface_ids = [azurerm_network_interface.webvm_nic.id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }

  # ✅ FIXED custom_data syntax
  custom_data = base64encode(<<-EOF
<powershell>
Install-WindowsFeature -Name Web-Server -IncludeManagementTools
</powershell>
EOF
  )
}

# VPN Gateway Public IP
resource "azurerm_public_ip" "gateway_public_ip" {
  name                = "gateway-ip"
  location            = azurerm_resource_group.app_rg.location
  resource_group_name = azurerm_resource_group.app_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# VPN Gateway - ✅ AzureRM 3.x syntax
resource "azurerm_virtual_network_gateway" "app_gateway" {
  name                = "app-gateway"
  location            = azurerm_resource_group.app_rg.location
  resource_group_name = azurerm_resource_group.app_rg.name
  type                = "Vpn"                    # ✅ REQUIRED in 3.x
  vpn_type            = "RouteBased"             # ✅ REQUIRED
  sku                 = "VpnGw2"                 # ✅ SKU name
  generation          = "Generation2"            # ✅ Gen2
  
  ip_configuration {
    public_ip_address_id = azurerm_public_ip.gateway_public_ip.id
    subnet_id            = azurerm_subnet.gateway_subnet.id
  }
}