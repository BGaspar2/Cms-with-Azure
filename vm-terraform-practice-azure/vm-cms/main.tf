resource "random_pet" "rg_name" {
  prefix = var.resource_group_name_prefix
}
resource "azurerm_resource_group" "rg" {
  location = var.resource_group_location
  name     = random_pet.rg_name.id
}
# Create virtual network
resource "azurerm_virtual_network" "my_cms_network" {
  name                = "myCMSnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}
# Create subnet
resource "azurerm_subnet" "my_cms_subnet" {
  name                 = "mySubnetCMS"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.my_cms_network.name
  address_prefixes     = ["10.0.1.0/24"]
}
# Create public IPs
resource "azurerm_public_ip" "my_cms_public_ip" {
  name                = "myPublicIPCMS"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}
# Create Network Security Group and rule
resource "azurerm_network_security_group" "my_cms_nsg" {
  name                = "myNetworkSecurityGroupCMS"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "HTTPS"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "HTTP"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
# Create network interface
resource "azurerm_network_interface" "my_cms_nic" {
  name                = "myCMSNIC"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  ip_configuration {
    name                          = "my_cmsnic_configuration"
    subnet_id                     = azurerm_subnet.my_cms_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.my_cms_public_ip.id
  }
}
# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "exampleCMS" {
  network_interface_id      = azurerm_network_interface.my_cms_nic.id
  network_security_group_id = azurerm_network_security_group.my_cms_nsg.id
}
# Generate random text for a unique storage account name
resource "random_id" "random_idcms" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.rg.name
  }
  byte_length = 8
}
# Create storage account for boot diagnostics
resource "azurerm_storage_account" "my_storagecms_account" {
  name                     = "diag${random_id.random_idcms.hex}"
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}
# Create (and display) an SSH key
resource "tls_private_key" "examplecms_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
# Create virtual machine cms
resource "azurerm_linux_virtual_machine" "my_cms_vm" {
  name                  = "vm-terraform-cms"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.my_cms_nic.id]
  custom_data = base64encode(file("scripts/init.sh"))
  size                  = "Standard_DS1_v2"
  os_disk {
    name                 = "myOsDiskCMS"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts-gen2"
    version   = "latest"
  }
  computer_name                   = "vm-terraform-cms"
  admin_username                  = "bryan-gaspar"
  admin_password                  = "0850594573@Bg"
  disable_password_authentication = false
  admin_ssh_key {
    username   = "bryan-gaspar"
    public_key = tls_private_key.examplecms_ssh.public_key_openssh
  }
  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.my_storagecms_account.primary_blob_endpoint
  }
}
