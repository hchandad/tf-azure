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
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

# Variables

variable "admin_username" {
  description = "User to be created with sudo priveleges"
  type        = string
}
variable "public_key" {
  description = "path to the public key to be added to the authorized_keys on the vm"
  type        = string
}

variable "domain_name" {
  description = "Fully qualifed domain name to attach to the instance"
  type        = string
}

variable "cloudflare_api_token" {
  description = "Cloudflare api token to update the dns A records"
  type        = string
}

variable "cloudlflare_account_id" {
  description = "Cloudflare account id"
  type        = string
}

# Providers
# Relies on azure cli for authentication
provider "azurerm" {
  features {

  }
}

provider "random" {

}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Azure Definitions

resource "azurerm_resource_group" "cachet" {
  name     = "cachet"
  location = "eastus"
}

# Virtual Machine Network Definition
resource "azurerm_virtual_network" "cachet" {
  name                = "cachet_vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.cachet.location
  resource_group_name = azurerm_resource_group.cachet.name
}

resource "azurerm_subnet" "cachet" {
  name                 = "cachet_subnet"
  resource_group_name  = azurerm_resource_group.cachet.name
  virtual_network_name = azurerm_virtual_network.cachet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "cachet" {
  name                = "cachet_public_ip"
  location            = azurerm_resource_group.cachet.location
  resource_group_name = azurerm_resource_group.cachet.name
  allocation_method   = "Dynamic"
}

resource "azurerm_network_security_group" "allow_ssh_http" {
  name                = "cachet"
  location            = azurerm_resource_group.cachet.location
  resource_group_name = azurerm_resource_group.cachet.name

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
}

resource "azurerm_network_interface" "cachet" {
  name                = "cachet_nic"
  location            = azurerm_resource_group.cachet.location
  resource_group_name = azurerm_resource_group.cachet.name

  ip_configuration {
    name                          = "internal"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.cachet.id
    public_ip_address_id          = azurerm_public_ip.cachet.id
  }
}

resource "azurerm_network_interface_security_group_association" "this" {
  network_interface_id      = azurerm_network_interface.cachet.id
  network_security_group_id = azurerm_network_security_group.allow_ssh_http.id
}

# Virtual Machine Definition
resource "azurerm_linux_virtual_machine" "cachet" {
  name                = "cachet"
  location            = azurerm_resource_group.cachet.location
  resource_group_name = azurerm_resource_group.cachet.name
  size                = "Standard_D2pls_v5"
  admin_username      = var.admin_username

  network_interface_ids = [azurerm_network_interface.cachet.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.public_key)
  }

  os_disk {
    name                 = "cachet"
    caching              = "None"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = 32
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-noble-daily"
    sku       = "24_04-daily-lts-arm64"
    version   = "latest"
  }
}

# Dns

resource "cloudflare_zone" "this" {
  account_id = var.cloudlflare_account_id
  zone       = "hchandad.dev"
}

resource "cloudflare_record" "cachet" {
  zone_id = cloudflare_zone.this.id
  name    = var.domain_name
  value   = azurerm_linux_virtual_machine.cachet.public_ip_address
  type    = "A"
  proxied = false
  ttl     = "300"
}

# Output
resource "local_file" "env" {
  content = templatefile("./templates/env.tftpl", {
    instance_ip    = azurerm_linux_virtual_machine.cachet.public_ip_address
    admin_username = var.admin_username
    domain_name    = var.domain_name
  })
  filename = ".env"
}

resource "local_file" "hosts" {
  content = templatefile("./templates/hosts.tftpl", {
    host = azurerm_linux_virtual_machine.cachet.name
    ip   = azurerm_linux_virtual_machine.cachet.public_ip_address
  })
  filename = "hosts"
}
