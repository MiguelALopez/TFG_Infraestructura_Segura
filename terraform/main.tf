# 1. Grupo de Recursos (usa el existente en lugar de crearlo)
data "azurerm_resource_group" "rg" {
  name = "rg-tfg-micky-wordpress"
}

# 2. Red Virtual (VNet)
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-tfg-segura"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# 3. Subred
resource "azurerm_subnet" "subnet" {
  name                 = "snet-wordpress-prod"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# 4. Grupo de Seguridad (NSG)
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-wordpress-prod"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "allow_ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow_http"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow_https"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# 5. Asociación NSG
resource "azurerm_subnet_network_security_group_association" "snet_nsg_assoc" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# 6. IP Pública
resource "azurerm_public_ip" "pip" {
  name                = "pip-lb-wordpress"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"

  lifecycle {
    ignore_changes = [
      zones,
      domain_name_label,
    ]
  }
}

# 7. Interfaz de Red (NIC)
resource "azurerm_network_interface" "nic" {
  name                = "nic-wordpress-prod"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig-wordpress"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# 8. Máquina Virtual
resource "azurerm_linux_virtual_machine" "vm" {
  name                = "vm-wordpress-prod-1"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_D2d_v4"
  admin_username      = var.admin_username
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  admin_password                  = var.vm_admin_password
  disable_password_authentication = false

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

# 9. Azure Key Vault
data "azurerm_client_config" "current" {}

resource "random_id" "vault_id" {
  byte_length = 4
}

resource "azurerm_key_vault" "tfg_vault" {
  name                        = "tfg-vault-micky-${random_id.vault_id.hex}"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  sku_name                    = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Purge", "Recover"
    ]
  }
}

# 10. Secreto de base de datos
resource "azurerm_key_vault_secret" "db_password" {
  name         = "wp-db-password"
  value        = var.db_password
  key_vault_id = azurerm_key_vault.tfg_vault.id

  lifecycle {
    ignore_changes = [value]
  }
}

# 11. Outputs
output "public_ip_address" {
  value       = azurerm_public_ip.pip.ip_address
  description = "Dirección IP pública del Load Balancer"
}

output "key_vault_uri" {
  value       = azurerm_key_vault.tfg_vault.vault_uri
  description = "URI del Key Vault"
  sensitive   = true
}

output "key_vault_name" {
  value       = azurerm_key_vault.tfg_vault.name
  description = "Nombre del Key Vault"
}