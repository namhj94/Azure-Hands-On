# Configure the Azure Provider
provider "azurerm" {
  # whilst the `version` attribute is optional, we recommend pinning to a given version of the Provider
  version = ">= 2.40.0"
  features {}
}

# Create a resource group
resource "azurerm_resource_group" "hjrg" {
  name     = "handson-01"
  location = "eastus"
}

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "vnet01" {
  name                = "hj-vnet01"
  resource_group_name = azurerm_resource_group.hjrg.name
  location            = azurerm_resource_group.hjrg.location
  address_space       = ["10.0.0.0/8"]
}

# Create Subnet
resource "azurerm_subnet" "subnet01" {
  name  = "hj-subnet01"
  resource_group_name = azurerm_resource_group.hjrg.name
  virtual_network_name = azurerm_virtual_network.vnet01.name
  address_prefixes = [ "10.1.0.0/16" ] 
}

# Create NSG
resource "azurerm_network_security_group" "nsg01" {
  name = "hj-nsg"
  location = azurerm_resource_group.hjrg.location
  resource_group_name = azurerm_resource_group.hjrg.name
  security_rule {
      name  = "RDP"
      priority  = 100
      direction = "Inbound"
      access  = "Allow"
      protocol  = "Tcp"
      source_port_range = "*"
      destination_port_range  = 3389
      source_address_prefix = "*"
      destination_address_prefix  = "*"
  }
  security_rule {  
      name  = "http"
      priority  = 110
      direction = "Inbound"
      access  = "Allow"
      protocol  = "Tcp"
      source_port_range = "*"
      destination_port_range  = 80
      source_address_prefix = "*"
      destination_address_prefix  = "*"
    }
  security_rule {  
      name  = "icmp"
      priority  = 120
      direction = "Inbound"
      access  = "Allow"
      protocol  = "Icmp"
      source_port_range = "*"
      destination_port_range  = "*"
      source_address_prefix = "*"
      destination_address_prefix  = "*"
    }
}
resource "azurerm_subnet_network_security_group_association" "nsg01_subnet01" {
  subnet_id = azurerm_subnet.subnet01.id
  network_security_group_id = azurerm_network_security_group.nsg01.id
}

# Create Availability Set
resource "azurerm_availability_set" "avset01" {
  name = "hj-avset01"
  location = azurerm_resource_group.hjrg.location
  resource_group_name = azurerm_resource_group.hjrg.name
}
# Create NIC
resource "azurerm_network_interface" "nic01" {
  name = "hj-nic01"
  location = azurerm_resource_group.hjrg.location
  resource_group_name = azurerm_resource_group.hjrg.name

  ip_configuration {
    name  = "internal"
    subnet_id = azurerm_subnet.subnet01.id
    private_ip_address_allocation = "Dynamic"
  }
}
# Create Winow Virtual Machines
resource "azurerm_windows_virtual_machine" "wvm01" {
  name                = "hj-wvm01"
  resource_group_name = azurerm_resource_group.hjrg.name
  location            = azurerm_resource_group.hjrg.location
  size                = "Standard_DS1_v2"
  admin_username      = "azureuser"
  admin_password      = "<PASSWORD>"
  network_interface_ids = [
    azurerm_network_interface.nic01.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }
}

# Create LB
resource "azurerm_public_ip" "extlb_pip" {
  name                = "PublicIPForLB"
  location            = "East US"
  resource_group_name = azurerm_resource_group.hjrg.name
  allocation_method   = "Static"
}

resource "azurerm_lb" "extlb" {
  name                = "TestLoadBalancer"
  location            = "East US"
  resource_group_name = azurerm_resource_group.hjrg.name

  frontend_ip_configuration {
    name                 = "hj-PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.extlb_pip.id
  }
}

resource "azurerm_lb_backend_address_pool" "extlb_bepool" {
  resource_group_name = azurerm_resource_group.hjrg.name
  loadbalancer_id     = azurerm_lb.extlb.id
  name                = "BackEndAddressPool"
}
resource "azurerm_network_interface_backend_address_pool_association" "example" {
  network_interface_id    = azurerm_network_interface.nic01.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.extlb_bepool.id
}

resource "azurerm_lb_nat_rule" "extlb_natrule" {
  resource_group_name            = azurerm_resource_group.hjrg.name
  loadbalancer_id                = azurerm_lb.extlb.id
  name                           = "RDPAccess"
  protocol                       = "Tcp"
  frontend_port                  = 5000
  backend_port                   = 3389
  frontend_ip_configuration_name = "hj-PublicIPAddress"
}

resource "azurerm_network_interface_nat_rule_association" "nic_natrule" {
  network_interface_id  = azurerm_network_interface.nic01.id
  ip_configuration_name = "internal"
  nat_rule_id           = azurerm_lb_nat_rule.extlb_natrule.id
}

resource "azurerm_lb_probe" "extlb_hp" {
  resource_group_name = azurerm_resource_group.hjrg.name
  loadbalancer_id     = azurerm_lb.extlb.id
  name                = "hj-probe"
  port                = 80
  protocol            = "http"
  request_path        = "/"
}

resource "azurerm_lb_rule" "example" {
  resource_group_name            = azurerm_resource_group.hjrg.name
  loadbalancer_id                = azurerm_lb.extlb.id
  name                           = "LBRule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "hj-PublicIPAddress"
  probe_id = azurerm_lb_probe.extlb_hp.id
  backend_address_pool_id = azurerm_lb_backend_address_pool.extlb_bepool.id
}