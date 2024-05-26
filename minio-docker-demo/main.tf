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
    cloudflare = {
      source = "cloudflare/cloudflare"
      version = "~> 4.0"
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

variable "cloudflare_api_token" {
  description = "cloudflare api token, you can generate one from MyProfile > ApiTokens" 
  type = string
}

variable "cloudlflare_account_id" {
  description = "cloudflare account id, get it from the dashboard url"
  type = string
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token 
}

variable "admin_username" {
  description = "minio vm sudo user"
  type        = string
  default     = "minio"
}

variable "admin_public_key" {
    description = "initial public key to install in the vm"
    type = string
    default = "~/.ssh/id_rsa.pub"
}

resource "azurerm_resource_group" "minio_linux_vm_group" {
  name     = "minio_linux_vm_group"
  location = "uaenorth"
}

/* Vm Network */
resource "azurerm_virtual_network" "minio_linux_virtual_network" {
  name                = "minio_linux_vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.minio_linux_vm_group.location
  resource_group_name = azurerm_resource_group.minio_linux_vm_group.name
}

resource "azurerm_subnet" "minio_linux_network_subnet" {
  name                 = "minio_linux_subnet"
  resource_group_name  = azurerm_resource_group.minio_linux_vm_group.name
  virtual_network_name = azurerm_virtual_network.minio_linux_virtual_network.name
  address_prefixes     = ["10.0.1.0/24"]
}

/* Public Ip */
resource "azurerm_public_ip" "minio_linux_vm_public_ip" {
  name                = "minio_linux_vm_public_ip"
  location            = azurerm_resource_group.minio_linux_vm_group.location
  resource_group_name = azurerm_resource_group.minio_linux_vm_group.name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_security_group" "minio_linux_vm_security_group" {
  name                = "minio_linux_vm_security_group"
  location            = azurerm_resource_group.minio_linux_vm_group.location
  resource_group_name = azurerm_resource_group.minio_linux_vm_group.name

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
    name                       = "http"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "https"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  // ~TODO: update to allow http/https
}

resource "azurerm_network_interface" "minio_linux_nic" {
  name                = "minio_linux_nic"
  resource_group_name = azurerm_resource_group.minio_linux_vm_group.name
  location            = azurerm_resource_group.minio_linux_vm_group.location

  ip_configuration {
    name                          = "internal"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.minio_linux_network_subnet.id
    public_ip_address_id          = azurerm_public_ip.minio_linux_vm_public_ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "associate_security_group_to_linux_vm" {
  network_interface_id      = azurerm_network_interface.minio_linux_nic.id
  network_security_group_id = azurerm_network_security_group.minio_linux_vm_security_group.id
}

/* Vm */
resource "azurerm_linux_virtual_machine" "minio_test_vm" {
  name                = "minio_test_vm"
  resource_group_name = azurerm_resource_group.minio_linux_vm_group.name
  location            = azurerm_resource_group.minio_linux_vm_group.location
  // TODO: update size / and disk
  size           = "Standard_D8as_v5"
  admin_username = var.admin_username

  network_interface_ids = [azurerm_network_interface.minio_linux_nic.id]

  admin_ssh_key {
    username   = "minio"
    public_key = file(var.admin_public_key)
  }

  os_disk {
    name                 = "minio_test_vm_os_disk"
    caching              = "ReadOnly"
    storage_account_type = "Premium_LRS"
    disk_size_gb = 1024
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  computer_name = "miniodemo"
}

resource "random_password" "minio_password" {
  length = 16
}

output "info" {
  value = {
    instance_ip = azurerm_linux_virtual_machine.minio_test_vm.public_ip_address
  }
  sensitive = true
}

resource "local_file" "hosts" {
  content = templatefile("./templates/hosts.tftpl", {
    host = azurerm_linux_virtual_machine.minio_test_vm.name
    ip   = azurerm_linux_virtual_machine.minio_test_vm.public_ip_address
  })
  filename = "hosts"
}

resource "local_file" "env" {
  content = templatefile("./templates/.env.tftpl", {
    instance_ip = azurerm_linux_virtual_machine.minio_test_vm.public_ip_address
    admin_username = var.admin_username
    minio_password = random_password.minio_password.result
  })
  filename = ".env"
}

// dns

resource "cloudflare_zone" "getcata_com" {
  account_id = var.cloudlflare_account_id
  zone = "getcata.com"
}

resource "cloudflare_record" "minio_demo_azure_getcata_com" {
  zone_id = cloudflare_zone.getcata_com.id
  name = "v1.minio.azure.getcata.com"  
  value = azurerm_linux_virtual_machine.minio_test_vm.public_ip_address
  type = "A"
  proxied = false
  ttl = "300"
}

resource "cloudflare_record" "console_minio_demo_azure_getcata_com" {
  zone_id = cloudflare_zone.getcata_com.id
  name = "console.v1.minio.azure.getcata.com"  
  value = azurerm_linux_virtual_machine.minio_test_vm.public_ip_address
  type = "A"
  proxied = false
  ttl = "300"
}