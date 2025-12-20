terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}

  resource_provider_registrations = "none"
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-udr-firewall-lab"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
  private_endpoint_vnet_policies = "Disabled"
}

resource "azurerm_subnet" "firewall" {
  name                                          = "firewall-subnet"
  resource_group_name                           = azurerm_resource_group.rg.name
  virtual_network_name                          = azurerm_virtual_network.vnet.name
  address_prefixes                              = ["10.0.0.0/24"]
  private_endpoint_network_policies             = "Disabled"
  private_link_service_network_policies_enabled = true
}

resource "azurerm_subnet" "workload_a" {
  name                                          = "workload-subnet-a"
  resource_group_name                           = azurerm_resource_group.rg.name
  virtual_network_name                          = azurerm_virtual_network.vnet.name
  address_prefixes                              = ["10.0.1.0/24"]
  private_endpoint_network_policies             = "Disabled"
  private_link_service_network_policies_enabled = true
}

resource "azurerm_subnet" "workload_b" {
  name                                          = "workload-subnet-b"
  resource_group_name                           = azurerm_resource_group.rg.name
  virtual_network_name                          = azurerm_virtual_network.vnet.name
  address_prefixes                              = ["10.0.2.0/24"]
  private_endpoint_network_policies             = "Disabled"
  private_link_service_network_policies_enabled = true
}

resource "azurerm_public_ip" "fw_pip" {
  name                = "pip-firewall"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
  sku_tier            = "Regional"
}

resource "azurerm_public_ip" "vm_a_pip" {
  name                = "pip-vm-a"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
  sku_tier            = "Regional"
}

resource "azurerm_public_ip" "vm_b_pip" {
  name                = "pip-vm-b"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  allocation_method   = "Static"
  sku                 = "Standard"
  sku_tier            = "Regional"
}

# FIXED: NSG for firewall VM (SSH access) - Priority 100
resource "azurerm_network_security_group" "fw_nsg" {
  name                = "nsg-firewall"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# FIXED: NSG for VM A - Priority 100
resource "azurerm_network_security_group" "vm_a_nsg" {
  name                = "nsg-vm-a"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# FIXED: NSG for VM B - Priority 100
resource "azurerm_network_security_group" "vm_b_nsg" {
  name                = "nsg-vm-b"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Network Interfaces (moved BEFORE NSG associations)
resource "azurerm_network_interface" "fw_nic" {
  name                = "nic-firewall"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.firewall.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.0.4"
    public_ip_address_id          = azurerm_public_ip.fw_pip.id
  }
}

resource "azurerm_network_interface" "vm_a_nic" {
  name                = "nic-vm-a"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.workload_a.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.4"
    public_ip_address_id          = azurerm_public_ip.vm_a_pip.id
  }
}

resource "azurerm_network_interface" "vm_b_nic" {
  name                = "nic-vm-b"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.workload_b.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.2.4"
    public_ip_address_id          = azurerm_public_ip.vm_b_pip.id
  }
}

# FIXED: NSG Associations (now AFTER NIC creation)
resource "azurerm_network_interface_security_group_association" "fw_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.fw_nic.id
  network_security_group_id = azurerm_network_security_group.fw_nsg.id
}

resource "azurerm_network_interface_security_group_association" "vm_a_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.vm_a_nic.id
  network_security_group_id = azurerm_network_security_group.vm_a_nsg.id
}

resource "azurerm_network_interface_security_group_association" "vm_b_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.vm_b_nic.id
  network_security_group_id = azurerm_network_security_group.vm_b_nsg.id
}

# VMs using variables
resource "azurerm_linux_virtual_machine" "fw_vm" {
  name                = "vm-firewall"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B2s"
  admin_username      = var.admin_username
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.fw_nic.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "osdisk-fw"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }
}

resource "azurerm_linux_virtual_machine" "vm_a" {
  name                = "vm-a"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B2s"
  admin_username      = var.admin_username
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.vm_a_nic.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "osdisk-vm-a"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }
}

resource "azurerm_linux_virtual_machine" "vm_b" {
  name                = "vm-b"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B2s"
  admin_username      = var.admin_username
  disable_password_authentication = true

  network_interface_ids = [
    azurerm_network_interface.vm_b_nic.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    name                 = "osdisk-vm-b"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }
}

# Route Table for UDR
resource "azurerm_route_table" "rt_workloads" {
  name                          = "rt-workloads-via-firewall"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  bgp_route_propagation_enabled = true
}

resource "azurerm_route" "route_all_via_fw" {
  name                   = "all-via-firewall"
  resource_group_name    = azurerm_resource_group.rg.name
  route_table_name       = azurerm_route_table.rt_workloads.name
  address_prefix         = "0.0.0.0/0"
  next_hop_type          = "VirtualAppliance"
  next_hop_in_ip_address = "10.0.0.4"
}

resource "azurerm_subnet_route_table_association" "workload_a_assoc" {
  subnet_id      = azurerm_subnet.workload_a.id
  route_table_id = azurerm_route_table.rt_workloads.id
}

resource "azurerm_subnet_route_table_association" "workload_b_assoc" {
  subnet_id      = azurerm_subnet.workload_b.id
  route_table_id = azurerm_route_table.rt_workloads.id
}
