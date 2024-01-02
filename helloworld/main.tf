terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {

  }
}

provider "random" {

}

variable "admin_username" {
  description = "linux vm sudo user"
  type        = string
  default     = "demo"
}

resource "azurerm_resource_group" "demo_linux_vm_group" {
  name     = "demo_linux_vm_group"
  location = "uaenorth"
}

/* Vm Network */
resource "azurerm_virtual_network" "demo_linux_virtual_network" {
  name                = "demo_linux_vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.demo_linux_vm_group.location
  resource_group_name = azurerm_resource_group.demo_linux_vm_group.name
}

resource "azurerm_subnet" "demo_linux_network_subnet" {
  name                 = "demo_linux_subnet"
  resource_group_name  = azurerm_resource_group.demo_linux_vm_group.name
  virtual_network_name = azurerm_virtual_network.demo_linux_virtual_network.name
  address_prefixes     = ["10.0.1.0/24"]
}



/* Public Ip */
resource "azurerm_public_ip" "demo_linux_vm_public_ip" {
  name                = "demo_linux_vm_public_ip"
  location            = azurerm_resource_group.demo_linux_vm_group.location
  resource_group_name = azurerm_resource_group.demo_linux_vm_group.name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_security_group" "demo_linux_vm_security_group" {
  name                = "demo_linux_vm_security_group"
  location            = azurerm_resource_group.demo_linux_vm_group.location
  resource_group_name = azurerm_resource_group.demo_linux_vm_group.name

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
}

resource "azurerm_network_interface" "demo_linux_nic" {
  name                = "demo_linux_nic"
  resource_group_name = azurerm_resource_group.demo_linux_vm_group.name
  location            = azurerm_resource_group.demo_linux_vm_group.location

  ip_configuration {
    name                          = "internal"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.demo_linux_network_subnet.id
    public_ip_address_id          = azurerm_public_ip.demo_linux_vm_public_ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "associate_security_group_to_linux_vm" {
  network_interface_id      = azurerm_network_interface.demo_linux_nic.id
  network_security_group_id = azurerm_network_security_group.demo_linux_vm_security_group.id
}

/* Vm */
resource "azurerm_linux_virtual_machine" "demo_test_vm" {
  name                = "demo_test_vm"
  resource_group_name = azurerm_resource_group.demo_linux_vm_group.name
  location            = azurerm_resource_group.demo_linux_vm_group.location
  size                = "Standard_DS1_v2"
  admin_username      = var.admin_username

  network_interface_ids = [azurerm_network_interface.demo_linux_nic.id]

  admin_ssh_key {
    username   = "demo"
    public_key = file("~/.ssh/wsl.pub")
  }

  os_disk {
    name                 = "demo_test_vm_os_disk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  computer_name = "helloazure"
}

/* Mysql */
resource "azurerm_resource_group" "demo_mysql_server_group" {
  name     = "demo_mysql_server_group"
  location = "uaenorth"
}

resource "random_password" "mysql_password" {
  length = 16
}

resource "azurerm_mysql_server" "demo_mysql_server" {
  name                = "demo-mysql-server"
  location            = azurerm_resource_group.demo_mysql_server_group.location
  resource_group_name = azurerm_resource_group.demo_mysql_server_group.name

  administrator_login          = var.admin_username
  administrator_login_password = random_password.mysql_password.result

  sku_name   = "B_Gen5_2"
  storage_mb = 5120
  version    = "5.7"

  auto_grow_enabled                 = true
  backup_retention_days             = 7
  geo_redundant_backup_enabled      = false
  infrastructure_encryption_enabled = false
  public_network_access_enabled     = true
  ssl_enforcement_enabled           = true
  ssl_minimal_tls_version_enforced  = "TLS1_2"
}

resource "azurerm_mysql_database" "demo_mysql_foo_database" {
  name                = "foo"
  resource_group_name = azurerm_resource_group.demo_mysql_server_group.name
  server_name         = azurerm_mysql_server.demo_mysql_server.name
  charset             = "utf8"
  collation           = "utf8_unicode_ci"
}

/* Flexible Mysql */

resource "azurerm_mysql_flexible_server" "demo_flexible_mysql_server" {
  name                   = "demo-flexible-mysql-server"
  resource_group_name    = azurerm_resource_group.demo_mysql_server_group.name
  location               = azurerm_resource_group.demo_mysql_server_group.location
  administrator_login    = var.admin_username
  administrator_password = random_password.mysql_password.result
  sku_name               = "B_Standard_B1s"
  zone                   = 3
  version                = "8.0.21"
}

resource "azurerm_mysql_flexible_database" "demo_bar_database" {
  name                = "bar"
  resource_group_name = azurerm_resource_group.demo_mysql_server_group.name
  server_name         = azurerm_mysql_flexible_server.demo_flexible_mysql_server.name
  charset             = "utf8mb3"
  collation           = "utf8mb3_unicode_ci"
}

// allow access to our flexible mysql server from our mysql vm
resource "azurerm_mysql_flexible_server_firewall_rule" "allow_demo_test_vm" {
  name                = "allow_demo_test_vm"
  resource_group_name = azurerm_resource_group.demo_mysql_server_group.name
  server_name         = azurerm_mysql_flexible_server.demo_flexible_mysql_server.name
  start_ip_address    = azurerm_linux_virtual_machine.demo_test_vm.public_ip_address
  end_ip_address      = azurerm_linux_virtual_machine.demo_test_vm.public_ip_address
}

output "info" {
  value = {
    mysql_password = azurerm_mysql_server.demo_mysql_server.administrator_login_password
    instance_ip    = azurerm_linux_virtual_machine.demo_test_vm.public_ip_address
    mysql_host     = azurerm_mysql_flexible_server.demo_flexible_mysql_server.fqdn
  }
  sensitive = true
}

resource "local_file" "hosts" {
  content = templatefile("./templates/hosts.tftpl", {
    host = azurerm_linux_virtual_machine.demo_test_vm.name
    ip   = azurerm_linux_virtual_machine.demo_test_vm.public_ip_address
  })
  filename = "hosts"
}