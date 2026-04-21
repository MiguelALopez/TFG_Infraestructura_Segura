# ============================================================
# TFG - Automatización de Infraestructura Segura en Azure
# Autor: Miguel Ángel Torres López
# ============================================================

# ============================================================
# 1. GRUPO DE RECURSOS
# ============================================================
resource "azurerm_resource_group" "rg" {
  name     = "rg-tfg-micky-wordpress"
  location = var.location
}

# ============================================================
# 2. RED VIRTUAL (VNet) Y SUBRED
# ============================================================
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-tfg-segura"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "snet-wordpress-prod"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  depends_on           = [azurerm_virtual_network.vnet]
}

# ============================================================
# 3. GRUPO DE SEGURIDAD DE RED (NSG) - Firewall Capa 4
# ============================================================
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

resource "azurerm_subnet_network_security_group_association" "snet_nsg_assoc" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
  depends_on                = [azurerm_subnet.subnet, azurerm_network_security_group.nsg]
}

# ============================================================
# 4. LOAD BALANCER - Alta Disponibilidad
# ============================================================
resource "azurerm_public_ip" "pip_lb" {
  name                = "pip-lb-wordpress"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb" "lb" {
  name                = "lb-wordpress-prod"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "frontend-lb-wordpress"
    public_ip_address_id = azurerm_public_ip.pip_lb.id
  }
}

resource "azurerm_lb_backend_address_pool" "lb_backend" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "pool-wordpress"
}

resource "azurerm_lb_probe" "lb_probe" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "check-http-80"
  protocol        = "Http"
  port            = 80
  request_path    = "/"
}

resource "azurerm_lb_rule" "lb_rule_http" {
  loadbalancer_id                = azurerm_lb.lb.id
  name                           = "rule-http-80"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "frontend-lb-wordpress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.lb_backend.id]
  probe_id                       = azurerm_lb_probe.lb_probe.id
}

resource "azurerm_lb_rule" "lb_rule_https" {
  loadbalancer_id                = azurerm_lb.lb.id
  name                           = "rule-https-443"
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = "frontend-lb-wordpress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.lb_backend.id]
  probe_id                       = azurerm_lb_probe.lb_probe.id
}

# ============================================================
# 5. INTERFACES DE RED Y MÁQUINAS VIRTUALES (x2)
# ============================================================

# --- VM 1 ---
resource "azurerm_public_ip" "pip_vm1" {
  name                = "vm-wordpress-prod-1-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "nic_vm1" {
  name                = "nic-wordpress-prod"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig-vm1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip_vm1.id
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "nic_vm1_lb" {
  network_interface_id    = azurerm_network_interface.nic_vm1.id
  ip_configuration_name   = "ipconfig-vm1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lb_backend.id
}

resource "azurerm_linux_virtual_machine" "vm1" {
  name                  = "vm-wordpress-prod-1"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = "Standard_D2d_v4"
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.nic_vm1.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

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

# --- VM 2 ---
resource "azurerm_public_ip" "pip_vm2" {
  name                = "vm-wordpress-prod-2-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "nic_vm2" {
  name                = "nic-wordpress-prod-2"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig-vm2"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pip_vm2.id
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "nic_vm2_lb" {
  network_interface_id    = azurerm_network_interface.nic_vm2.id
  ip_configuration_name   = "ipconfig-vm2"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lb_backend.id
}

resource "azurerm_linux_virtual_machine" "vm2" {
  name                  = "vm-wordpress-prod-2"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = azurerm_resource_group.rg.location
  size                  = "Standard_D2d_v4"
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.nic_vm2.id]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.ssh_public_key
  }

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

# ============================================================
# 6. BASE DE DATOS MySQL (PaaS - Azure Database for MySQL)
# ============================================================
resource "azurerm_mysql_flexible_server" "mysql" {
  name                   = "tfg-mysql-micky"
  resource_group_name    = azurerm_resource_group.rg.name
  location               = azurerm_resource_group.rg.location
  administrator_login    = var.db_admin_user
  administrator_password = var.db_password
  sku_name               = "B_Standard_B1ms"
  version                = "8.0.21"

  storage {
    size_gb = 20
  }

  backup_retention_days = 7
}

resource "azurerm_mysql_flexible_database" "wordpress_db" {
  name                = "wordpress_db"
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_mysql_flexible_server.mysql.name
  charset             = "utf8mb4"
  collation           = "utf8mb4_unicode_ci"
}

resource "azurerm_mysql_flexible_server_firewall_rule" "allow_azure_services" {
  name                = "allow-azure-services"
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_mysql_flexible_server.mysql.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}

# ============================================================
# 7. AZURE KEY VAULT - Gestión Segura de Secretos
# ============================================================
data "azurerm_client_config" "current" {}

resource "random_id" "vault_id" {
  byte_length = 4
}

resource "azurerm_key_vault" "tfg_vault" {
  name                        = "tfg-vault-micky-${random_id.vault_id.hex}"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false
  enabled_for_disk_encryption = true

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    secret_permissions = [
      "Get", "List", "Set", "Delete", "Purge", "Recover"
    ]
  }
}

resource "azurerm_key_vault_secret" "db_password" {
  name         = "wp-db-password"
  value        = var.db_password
  key_vault_id = azurerm_key_vault.tfg_vault.id

  lifecycle {
    ignore_changes = [value]
  }
}

# ============================================================
# 8. OUTPUTS
# ============================================================
output "lb_public_ip" {
  value       = azurerm_public_ip.pip_lb.ip_address
  description = "IP pública del Load Balancer"
}

output "vm1_public_ip" {
  value       = azurerm_public_ip.pip_vm1.ip_address
  description = "IP pública de vm-wordpress-prod-1"
}

output "vm2_public_ip" {
  value       = azurerm_public_ip.pip_vm2.ip_address
  description = "IP pública de vm-wordpress-prod-2"
}

output "key_vault_uri" {
  value       = azurerm_key_vault.tfg_vault.vault_uri
  description = "URI del Azure Key Vault"
  sensitive   = true
}

output "mysql_endpoint" {
  value       = azurerm_mysql_flexible_server.mysql.fqdn
  description = "Endpoint del servidor MySQL"
}
