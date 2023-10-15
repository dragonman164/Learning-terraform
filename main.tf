# Specifying Provider for Azure Cloud Connection
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.91.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Creating Azure Resource Group 
resource "azurerm_resource_group" "mtc-rg" {
  name     = "mtc-resources"
  location = "East Us"
  tags = {
    environment = "dev"
  }
}

# Terraform Virtual Network
resource "azurerm_virtual_network" "mtc-vm" {
  name                = "mtc-network"
  resource_group_name = azurerm_resource_group.mtc-rg.name
  location            = azurerm_resource_group.mtc-rg.location
  address_space       = ["10.123.0.0/16"]

  tags = {
    environment = "dev"
  }


}

# Subnets for your Virtual Network
resource "azurerm_subnet" "mtc-subnet" {
  name                 = "mtc-subnet"
  resource_group_name  = azurerm_resource_group.mtc-rg.name
  virtual_network_name = azurerm_virtual_network.mtc-vm.name
  address_prefixes     = ["10.123.1.0/24"]

}

#Security Group for our Network 
resource "azurerm_network_security_group" "mtc-sg" {
  name                = "mtc-rg"
  location            = azurerm_resource_group.mtc-rg.location
  resource_group_name = azurerm_resource_group.mtc-rg.name
  tags = {
    environment = "dev"
  }

}

# Security Rule for Our Network (Unassociated)
resource "azurerm_network_security_rule" "mtc-dev-rule" {
  name                        = "mtc-dev-rule"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.mtc-rg.name
  network_security_group_name = azurerm_network_security_group.mtc-sg.name
}


# Rule for NSG and Virtual Network Association
resource "azurerm_subnet_network_security_group_association" "mtc-sga" {
  subnet_id                 = azurerm_subnet.mtc-subnet.id
  network_security_group_id = azurerm_network_security_group.mtc-sg.id
}


# Public IP (Not Associated)
resource "azurerm_public_ip" "mtc-ip" {
  name                = "mtc-ip"
  resource_group_name = azurerm_resource_group.mtc-rg.name
  location            = azurerm_resource_group.mtc-rg.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "dev"
  }
}

# Linking aur public ID to subnet using NIC
resource "azurerm_network_interface" "mtc-nic" {
  name                = "mtc-nic"
  location            = azurerm_resource_group.mtc-rg.location
  resource_group_name = azurerm_resource_group.mtc-rg.name


  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.mtc-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.mtc-ip.id
  }
  tags = {
    environment = "dev"
  }

}

# Create Azure VM linked with NIC
resource "azurerm_virtual_machine" "main" {
  name                = "mtc-vm"
  resource_group_name = azurerm_resource_group.mtc-rg.name
  location            = azurerm_resource_group.mtc-rg.location
  vm_size             = "Standard_B1s"

  network_interface_ids = [azurerm_network_interface.mtc-nic.id]


  storage_os_disk {
    name              = "mtc-disk"
    caching           = "ReadWrite"
    managed_disk_type = "Standard_LRS"
    create_option     = "FromImage"
  }
  os_profile {
    computer_name  = "mtc-vm"
    admin_username = "dragonman165"
    admin_password = "HamChorHai123"
    custom_data    = filebase64("customdata.tpl")

  }


  os_profile_linux_config {
    disable_password_authentication = false
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }



  tags = {
    environment = "dev"
  }
}

# Data Source <for accessing details> (not azure resource)
data "azurerm_public_ip" "mtc-ip-data" {
  name = azurerm_public_ip.mtc-ip.name
  resource_group_name = azurerm_resource_group.mtc-rg.name
}

# Output to be displayed (Not a resource)
output "public_ip_address" {
    value = "${azurerm_virtual_machine.main.name}: ${data.azurerm_public_ip.mtc-ip-data.ip_address}"
}