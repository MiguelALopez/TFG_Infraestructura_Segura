# 🔄 Azure Pipeline - Configuración CI/CD

## Descripción

Este archivo define un pipeline de **CI/CD completo** para el despliegue automatizado de la infraestructura del TFG en Azure. Automatiza el aprovisionamiento con **Terraform**, la configuración con **Ansible** y las verificaciones de seguridad.

---

## 📋 Stages del Pipeline

### 1️⃣ **Validation** - Validación y Auditoría de Seguridad
**Jobs:**
- **SecurityAudit:** Verifica que no haya archivos sensibles en Git y escanea credenciales hardcodeadas
- **TerraformValidation:** Valida sintaxis y formato de Terraform
- **AnsibleValidation:** Verifica sintaxis de playbooks de Ansible

### 2️⃣ **TerraformPlan** - Preview de Cambios
**Jobs:**
- **Plan:** Genera plan de Terraform mostrando qué recursos se crearán/modificarán/eliminarán
- Publica el plan como artefacto para revisión

### 3️⃣ **TerraformApply** - Despliegue de Infraestructura
**Jobs:**
- **ApplyInfrastructure:** Aplica cambios de Terraform con **aprobación manual requerida**
- Solo se ejecuta en branch `main`
- Requiere environment `production-azure` configurado en Azure DevOps
- Captura outputs (IP pública, Key Vault)

### 4️⃣ **AnsibleDeploy** - Configuración de Servidores
**Jobs:**
- **ConfigureServers:** Ejecuta playbook de Ansible para configurar VMs
- Genera inventario dinámico desde Azure
- Recupera secretos desde Azure Key Vault
- Despliega containers Docker con WordPress

### 5️⃣ **PostDeploymentTests** - Verificación
**Jobs:**
- **HealthCheck:** Verifica que la aplicación responda correctamente
- Muestra resumen del despliegue

---

## ⚙️ Configuración Requerida en Azure DevOps

### 1. Service Connection
Crea una **Service Connection** llamada `Azure-ServiceConnection-TFG`:

1. Ve a **Project Settings** → **Service connections**
2. **New service connection** → **Azure Resource Manager**
3. **Service principal (automatic)**
4. Selecciona tu suscripción
5. Nombre: `Azure-ServiceConnection-TFG`

### 2. Environment para Aprobaciones
Crea un **Environment** llamado `production-azure`:

1. Ve a **Pipelines** → **Environments**
2. **New environment** → Nombre: `production-azure`
3. En **Approvals and checks** → **Approvals**
4. Añade aprobadores (tú mismo u otros miembros del equipo)

### 3. Variables de Pipeline
Configura estas **variables secretas** en el pipeline:

| Variable | Descripción | Ejemplo |
|----------|-------------|---------|
| `TF_VAR_admin_username` | Usuario admin de las VMs | `azureuser` |
| `TF_VAR_ssh_public_key` | Clave SSH pública | `ssh-rsa AAAAB3...` |
| `TF_VAR_location` | Región de Azure | `France Central` |
| `TF_VAR_vm_admin_password` | Contraseña de VMs | `********` (secreto) |
| `TF_VAR_db_password` | Contraseña de MySQL | `********` (secreto) |
| `ANSIBLE_USER` | Usuario Ansible | `azureuser` |
| `VM_IP_1` | IP de VM 1 (opcional) | `20.123.45.67` |
| `VM_IP_2` | IP de VM 2 (opcional) | `20.123.45.68` |
| `KEYVAULT_URI` | URI del Key Vault | `https://tfg-vault-...` |

**Para configurar variables:**
1. Ve a **Pipelines** → Selecciona el pipeline → **Edit**
2. **Variables** → **New variable**
3. Marca **Keep this value secret** para las contraseñas

### 4. Secure Files
Sube la **clave SSH privada** como Secure File:

1. Ve a **Pipelines** → **Library** → **Secure files**
2. **+ Secure file**
3. Sube `ansible_id_rsa` (tu clave privada SSH)

### 5. Extensiones de Azure DevOps
Instala estas extensiones desde el **Marketplace**:

- **Terraform (Microsoft)**: https://marketplace.visualstudio.com/items?itemName=ms-devlabs.custom-terraform-tasks
- **Azure CLI** (viene instalada por defecto)

---

## 🚀 Cómo Ejecutar el Pipeline

### Opción 1: Desde Azure DevOps UI

1. Ve a **Pipelines** → **New pipeline**
2. Selecciona **Azure Repos Git** (si usas Azure Repos) o **GitHub**
3. Selecciona el repositorio `TFG_Infraestructura_Segura`
4. **Existing Azure Pipelines YAML file**
5. Selecciona `/azure-pipelines.yml`
6. **Run**

### Opción 2: Push a `main` (Trigger Automático)

```bash
git push origin main
```

El pipeline se ejecutará automáticamente cuando se detecten cambios en `main`.

---

## 🔒 Seguridad del Pipeline

### Controles Implementados:

✅ **Validación de .gitignore:** Verifica que no haya archivos sensibles commiteados
✅ **Escaneo de credenciales:** Busca contraseñas hardcodeadas en código
✅ **Terraform Validation:** Valida sintaxis antes de apply
✅ **Aprobación manual:** Stage de Apply requiere aprobación humana
✅ **Variables secretas:** Contraseñas almacenadas como variables secretas
✅ **Secure Files:** Claves SSH almacenadas de forma segura
✅ **Branch protection:** Apply solo en `main`

---

## 📊 Flujo de Ejecución

```
┌────────────────────────────────────────────────────────┐
│  TRIGGER: Push a main                                  │
└────────────────────┬───────────────────────────────────┘
                     ↓
┌────────────────────────────────────────────────────────┐
│  STAGE 1: Validation                                   │
│  ├─ Security Audit (archivos sensibles, passwords)     │
│  ├─ Terraform Validate                                 │
│  └─ Ansible Syntax Check                               │
└────────────────────┬───────────────────────────────────┘
                     ↓
┌────────────────────────────────────────────────────────┐
│  STAGE 2: Terraform Plan                               │
│  └─ Genera preview de cambios                          │
└────────────────────┬───────────────────────────────────┘
                     ↓
┌────────────────────────────────────────────────────────┐
│  STAGE 3: Terraform Apply 🔐 APROBACIÓN REQUERIDA      │
│  ├─ Espera aprobación manual                           │
│  ├─ Aplica infraestructura                             │
│  └─ Captura outputs (IP, Key Vault)                    │
└────────────────────┬───────────────────────────────────┘
                     ↓
┌────────────────────────────────────────────────────────┐
│  STAGE 4: Ansible Deploy                               │
│  ├─ Genera inventario dinámico                         │
│  ├─ Configura servidores                               │
│  └─ Despliega Docker containers                        │
└────────────────────┬───────────────────────────────────┘
                     ↓
┌────────────────────────────────────────────────────────┐
│  STAGE 5: Post-Deployment Tests                        │
│  ├─ Health check HTTP                                  │
│  └─ Resumen del despliegue                             │
└────────────────────────────────────────────────────────┘
```

---

## 🛠️ Troubleshooting

### Error: "TerraformInstaller@1 not found"
**Solución:** Instala la extensión de Terraform desde el Marketplace de Azure DevOps

### Error: "Service connection not found"
**Solución:** Verifica que la Service Connection se llame exactamente `Azure-ServiceConnection-TFG`

### Error: "Environment 'production-azure' could not be found"
**Solución:** Crea el environment en Azure DevOps Pipelines → Environments

### Error: "Secure file 'ansible_id_rsa' not found"
**Solución:** Sube la clave SSH privada en Pipelines → Library → Secure files

### Error: Variables TF_VAR_* no definidas
**Solución:** Configura las variables en el pipeline (Variables → New variable)

---

## 📌 Notas Importantes

- El stage de **Terraform Apply** requiere **aprobación manual explícita** para evitar cambios accidentales
- Las contraseñas se pasan a Terraform mediante **variables de pipeline secretas**, nunca en código
- El pipeline solo se activa en cambios a `main`, excluyendo cambios a README.md y .gitignore
- Los outputs de Terraform se capturan automáticamente para usarse en stages posteriores
- El inventario de Ansible se genera dinámicamente desde Azure para evitar IPs hardcodeadas

---

## 🔄 Mejoras Futuras (Opcional)

- [ ] Terraform Backend en Azure Storage para compartir estado entre pipelines
- [ ] Tests de integración con Selenium/Playwright
- [ ] Terraform Destroy pipeline para limpiar recursos
- [ ] Notificaciones a Teams/Slack
- [ ] Terraform drift detection (ejecución programada para detectar cambios manuales)
