# ☁️ Automatización de Infraestructura Segura en Azure (TFG)

[![Terraform](https://img.shields.io/badge/Terraform-~4.0-623CE4?logo=terraform)](https://www.terraform.io/)
[![Ansible](https://img.shields.io/badge/Ansible-2.15+-EE0000?logo=ansible)](https://www.ansible.com/)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker)](https://www.docker.com/)
[![Azure](https://img.shields.io/badge/Cloud-Microsoft%20Azure-0078D4?logo=microsoftazure)](https://azure.microsoft.com/)
[![Azure DevOps](https://img.shields.io/badge/CI%2FCD-Azure%20DevOps-0078D4?logo=azuredevops)](https://dev.azure.com/)
[![Status](https://img.shields.io/badge/estado-completado-brightgreen)](https://github.com/)

**Autor:** Miguel Ángel Torres López
**Ciclo:** ASIR 2025-2026 | **Centro:** Cesur – GCoremsa

---

## 📋 Descripción

Este repositorio implementa el despliegue completamente automatizado de una infraestructura web en **Alta Disponibilidad** sobre **Microsoft Azure**, aplicando el paradigma de **Infraestructura como Código (IaC)** con principios de **hardening** y **seguridad por diseño**.

La solución despliega **WordPress** sobre dos máquinas virtuales balanceadas, con base de datos MySQL gestionada como PaaS, certificados SSL/TLS, y gestión de secretos mediante **Azure Key Vault**. Todo el ciclo de vida se automatiza mediante un **pipeline CI/CD en Azure DevOps** con aprobación manual antes del despliegue en producción.

---

## 🏗️ Arquitectura

```
Internet
    │
    ▼
┌─────────────────────────────┐
│   Azure Load Balancer       │  ← IP pública estática, Standard SKU
│   (HTTP :80 / HTTPS :443)   │    Health Probe TCP:80
└──────────┬──────────────────┘
           │ Distribución equitativa
    ┌──────┴──────┐
    ▼             ▼
┌───────────┐ ┌───────────┐
│  VM-1     │ │  VM-2     │  ← Ubuntu 22.04 LTS, Standard_D2d_v4
│  Nginx    │ │  Nginx    │  ← Reverse proxy SSL (Docker)
│  WordPress│ │  WordPress│  ← WordPress:latest (Docker)
└─────┬─────┘ └─────┬─────┘
      └──────┬───────┘
             ▼
┌────────────────────────────┐
│ Azure MySQL Flexible Server│  ← PaaS, B_Standard_B1ms, v8.0.21
│                            │    SSL obligatorio
└────────────────────────────┘

┌────────────────────────────┐
│    Azure Key Vault         │  ← Secreto: wp-db-password
│                            │    Ansible recupera en runtime
└────────────────────────────┘

Red: VNet 10.0.0.0/16 → Subnet 10.0.1.0/24
NSG: Permite 22 (SSH), 80 (HTTP), 443 (HTTPS)
```

---

## 🛠️ Stack Tecnológico

| Capa | Herramienta | Versión | Función |
|------|-------------|---------|---------|
| **IaC** | Terraform | ~4.0 (azurerm) | Aprovisionamiento completo de Azure |
| **Config** | Ansible | 2.15+ | Instalación Docker + despliegue WordPress |
| **Contenedor** | Docker + Compose | Latest | Nginx (proxy SSL) + WordPress |
| **CI/CD** | Azure DevOps Pipelines | YAML | 5 stages con aprobación manual |
| **Secretos** | Azure Key Vault | — | Contraseña DB, acceso por identidad gestionada |
| **BBDD** | Azure MySQL Flexible | 8.0.21 | PaaS, backups automáticos |
| **Proxy** | Nginx | 1.27-alpine | Reverse proxy + terminación SSL/TLS |

---

## 🔒 Seguridad Implementada

| Medida | Implementación |
|--------|----------------|
| Sin contraseñas en código | Secretos en Azure Key Vault; Ansible los recupera en runtime |
| Sin credenciales en repo | `.gitignore` excluye `*.tfvars`, `*.tfstate`, `hosts.ini`, `.env`, `wp-config.php`, claves SSH |
| Autenticación SSH | Acceso a VMs solo por clave pública (sin password) |
| Cifrado en tránsito | Nginx con SSL/TLS; MySQL con `MYSQL_CLIENT_FLAGS = MYSQLI_CLIENT_SSL` |
| Mínimo privilegio (NSG) | Solo puertos 22, 80 y 443 abiertos al exterior |
| Secrets en pipeline | Variables en grupo `TFG-Variables` de Azure DevOps; clave SSH como *Secure File* |
| Auditoría en CI | Stage 1 escanea credenciales hardcodeadas antes de cualquier despliegue |

---

## 📁 Estructura del Repositorio

```
TFG_Infraestructura_Segura/
├── azure-pipelines.yml          # Pipeline CI/CD (5 stages)
├── .gitignore                   # Protección de archivos sensibles
├── README.md
│
├── terraform/
│   ├── main.tf                  # Infraestructura completa (RG, VNet, NSG, LB, VMs, MySQL, KV)
│   ├── variables.tf             # Declaración de variables
│   ├── providers.tf             # Proveedores: azurerm ~4.0, random ~3.0
│   └── terraform.tfvars.example # Plantilla (sin credenciales reales)
│
└── ansible/
    ├── site.yml                 # Playbook principal: KV → Docker → WordPress
    ├── ansible.cfg.example      # Plantilla de configuración de Ansible
    ├── group_vars/
    │   └── wordpress_servers.yml  # Variables del grupo (host DB, URI Key Vault)
    ├── inventory/
    │   └── hosts.ini.example    # Plantilla de inventario (sin IPs reales)
    ├── playbooks/
    │   ├── install_docker.yml
    │   ├── deploy_wordpress.yml
    │   └── setup_firewall.yml
    └── deploy/
        ├── docker-compose.yml   # Servicios: WordPress + Nginx
        ├── generate-certs.sh    # Genera certificados SSL auto-firmados
        ├── .env.example         # Plantilla de variables de entorno
        └── nginx/
            └── default.conf     # Configuración Nginx reverse proxy
```

---

## 🚀 Guía de Despliegue Paso a Paso

> **Requisitos previos:**
> - Azure CLI instalado y sesión activa (`az login`)
> - Terraform >= 1.6
> - Ansible >= 2.15 con colección `azure.azcollection`
> - Python 3.8+

---

### PASO 1 — Clonar el repositorio

```bash
git clone https://github.com/TU_USUARIO/TFG_Infraestructura_Segura.git
cd TFG_Infraestructura_Segura
```

---

### PASO 2 — Generar claves SSH para las VMs

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/ansible_id_rsa -N ""

# Ver la clave pública (se necesita en el paso 3)
cat ~/.ssh/ansible_id_rsa.pub
```

---

### PASO 3 — Configurar variables de Terraform

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Editar `terraform/terraform.tfvars`:

```hcl
location       = "France Central"
admin_username = "azureuser"
ssh_public_key = "ssh-rsa AAAAB3NzaC1yc2E..."   # salida del paso anterior
db_admin_user  = "micky_admin"
db_password    = "TuPasswordMySQL_Seguro_456!"
```

> ⚠️ Este archivo está en `.gitignore`. **Nunca lo subas al repositorio.**

---

### PASO 4 — Desplegar infraestructura con Terraform

```bash
cd terraform

# Inicializar proveedores y módulos
terraform init

# Revisar el plan sin aplicar cambios
terraform plan

# Desplegar (~5-10 min)
terraform apply

# Anotar las IPs de la salida:
#   lb_public_ip   → acceso web al WordPress
#   vm1_public_ip  → IP directa VM-1 (para Ansible)
#   vm2_public_ip  → IP directa VM-2 (para Ansible)
#   key_vault_uri  → URI del Key Vault
```

---

### PASO 5 — Configurar Ansible

#### 5.1 Inventario con las IPs reales

```bash
cp ansible/inventory/hosts.ini.example ansible/inventory/hosts.ini
```

Editar `ansible/inventory/hosts.ini` con las IPs del paso anterior:

```ini
[wordpress_servers]
vm-prod-1 ansible_host=<IP_VM_1> ansible_user=azureuser ansible_ssh_private_key_file=~/.ssh/ansible_id_rsa
vm-prod-2 ansible_host=<IP_VM_2> ansible_user=azureuser ansible_ssh_private_key_file=~/.ssh/ansible_id_rsa

[all:vars]
ansible_python_interpreter=/usr/bin/python3
```

#### 5.2 Archivo de configuración de Ansible

```bash
cp ansible/ansible.cfg.example ansible/ansible.cfg
```

Verificar las rutas en `ansible/ansible.cfg`:

```ini
[defaults]
inventory         = ./inventory/hosts.ini
remote_user       = azureuser
private_key_file  = ~/.ssh/ansible_id_rsa
host_key_checking = False
```

#### 5.3 Instalar la colección de Azure

```bash
ansible-galaxy collection install azure.azcollection
pip install -r ~/.ansible/collections/ansible_collections/azure/azcollection/requirements.txt
```

---

### PASO 6 — Ejecutar el playbook de despliegue

```bash
cd ansible
ansible-playbook site.yml
```

El playbook realiza automáticamente:
1. Recupera el secreto `wp-db-password` desde Azure Key Vault (sin archivos locales con contraseñas)
2. Espera a que las VMs respondan por SSH
3. Limpia e instala Docker y Docker Compose
4. Copia los archivos de despliegue a cada VM
5. Genera el fichero `.env` con la contraseña obtenida del Key Vault
6. Levanta WordPress + Nginx con `docker-compose up -d`

---

### PASO 7 — Verificar el despliegue

```bash
# Comprobar respuesta del Load Balancer
curl -I http://<lb_public_ip>

# Acceder desde el navegador:
# http://<lb_public_ip>
```

---

## 🔄 Pipeline CI/CD — Azure DevOps

El fichero `azure-pipelines.yml` define **5 stages** con aprobación manual previa al despliegue en producción:

| Stage | Nombre | Descripción |
|-------|--------|-------------|
| 1 | **Validation** | Scan de credenciales hardcodeadas + `terraform validate` + sintaxis Ansible |
| 2 | **TerraformPlan** | `terraform plan` → artefacto `tfplan` |
| 3 | **TerraformApply** | ⏸️ Aprobación manual → `terraform apply tfplan` |
| 4 | **AnsibleDeploy** | Inventario dinámico vía Azure CLI + ejecución del playbook |
| 5 | **PostDeploymentTests** | Health check HTTP al Load Balancer |

### Recursos necesarios en Azure DevOps

| Recurso | Nombre | Descripción |
|---------|--------|-------------|
| Variable Group | `TFG-Variables` | `TF_VAR_admin_username`, `TF_VAR_ssh_public_key`, `TF_VAR_location`, `TF_VAR_db_admin_user`, `TF_VAR_db_password` *(secreta)*, `ANSIBLE_USER`, `KEYVAULT_URI` |
| Service Connection | `Azure-ServiceConnection-TFG` | Tipo Azure Resource Manager |
| Secure File | `ansible_id_rsa` | Clave privada SSH para Ansible |
| Environment | `production-azure` | Con aprobación manual configurada |

---

## 🧹 Destruir la infraestructura

```bash
cd terraform
terraform destroy
```

> ⚠️ Elimina **todos** los recursos de Azure de forma permanente.

---

## 📊 Coste Estimado (Pay-As-You-Go)

| Recurso | SKU | Coste aprox./mes |
|---------|-----|-----------------|
| 2× VM Ubuntu | Standard_D2d_v4 | ~50 € |
| Load Balancer | Standard SKU | ~18 € |
| MySQL Flexible Server | B_Standard_B1ms | ~13 € |
| Azure Key Vault | Operaciones | ~0 € |
| Storage + Red | — | ~5 € |
| **Total** | | **~86 €/mes** |

> Con **Azure for Students** (crédito $100): coste real = **0 €** hasta agotar crédito.

---

## 📝 Licencia

Proyecto académico — TFG ASIR 2025-2026. Uso educativo.
