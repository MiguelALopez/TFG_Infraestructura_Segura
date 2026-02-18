variable "location" {
  type        = string
  description = "Región de Azure donde se desplegarán los recursos"
}

variable "admin_username" {
  type        = string
  description = "Nombre de usuario administrativo para las máquinas virtuales"
}

variable "ssh_public_key" {
  type        = string
  description = "Clave pública SSH para autenticación"
}

variable "vm_admin_password" {
  type        = string
  description = "Contraseña de administrador para las máquinas virtuales"
  sensitive   = true
}

variable "db_password" {
  type        = string
  description = "Contraseña para Azure Database for MySQL"
  sensitive   = true
}