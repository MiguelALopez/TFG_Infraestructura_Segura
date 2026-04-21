variable "location" {
  type        = string
  description = "Región de Azure donde se desplegarán los recursos"
  default     = "France Central"
}

variable "admin_username" {
  type        = string
  description = "Nombre de usuario administrador para las máquinas virtuales"
  default     = "azureuser"
}

variable "ssh_public_key" {
  type        = string
  description = "Clave pública SSH para autenticación en las VMs"
}

variable "vm_admin_password" {
  type        = string
  description = "Contraseña de administrador para las VMs (alternativa a SSH)"
  sensitive   = true
  default     = null
}

variable "db_admin_user" {
  type        = string
  description = "Usuario administrador de Azure Database for MySQL"
  default     = "micky_admin"
}

variable "db_password" {
  type        = string
  description = "Contraseña para Azure Database for MySQL - se almacena en Key Vault"
  sensitive   = true
}
