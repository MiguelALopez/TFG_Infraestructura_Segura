# 🔧 Guía de Configuración de Azure Pipelines en Azure DevOps

## Requisitos Previos
- ✅ Cuenta de Azure activa
- ✅ Proyecto en Azure DevOps (ya lo tienes: `maikyCS/TFG_Infraestructura_Segura`)
- ✅ Repositorio pusheado a Azure Repos

---

## 📋 PASO 1: Instalar Extensiones Requeridas

### 1.1 Terraform Extension

1. Ve a: https://marketplace.visualstudio.com/items?itemName=ms-devlabs.custom-terraform-tasks
2. Click en **"Get it free"**
3. Selecciona tu organización: **maikyCS**
4. Click **"Install"**

### 1.2 Verificar Instalación

1. En Azure DevOps: https://dev.azure.com/maikyCS
2. **Organization Settings** (esquina inferior izquierda) → **Extensions**
3. Verifica que aparezca: **"Terraform"** (by Microsoft DevLabs)

✅ **Completado:** Las extensiones están instaladas

---

## 🔐 PASO 2: Crear Service Connection para Azure

### 2.1 Acceder a Service Connections

1. Ve a tu proyecto: https://dev.azure.com/maikyCS/TFG_Infraestructura_Segura
2. Click en **⚙️ Project Settings** (esquina inferior izquierda)
3. En el menú izquierdo: **Pipelines** → **Service connections**

### 2.2 Crear Nueva Service Connection

1. Click **"New service connection"** (esquina superior derecha)
2. Selecciona: **"Azure Resource Manager"**
3. Click **"Next"**

### 2.3 Configurar Service Principal (Automático)

1. Método de autenticación: **"Service principal (automatic)"** (recomendado)
2. Scope level: **"Subscription"**
3. Selecciona tu **Subscription** (donde están los recursos de Azure)
4. Resource group: **Déjalo vacío** (para acceso a toda la suscripción)
5. Service connection name: **`Azure-ServiceConnection-TFG`** ⚠️ IMPORTANTE: debe ser exactamente este nombre
6. Description: `Service Connection para despliegue automatizado del TFG`
7. ✅ Marca: **"Grant access permission to all pipelines"**
8. Click **"Save"**

### 2.4 Verificar

Deberías ver la nueva conexión en la lista con:
- Name: `Azure-ServiceConnection-TFG`
- Type: `Azure Resource Manager`
- Ready: ✅ (icono verde)

✅ **Completado:** Service Connection configurada

---

## 🌍 PASO 3: Crear Environment para Aprobaciones Manuales

### 3.1 Acceder a Environments

1. En tu proyecto: **Pipelines** (menú izquierdo)
2. Click en **"Environments"**

### 3.2 Crear Nuevo Environment

1. Click **"New environment"** (esquina superior derecha)
2. Name: **`production-azure`** ⚠️ IMPORTANTE: exactamente este nombre
3. Description: `Entorno de producción de Azure - requiere aprobación manual`
4. Resource: **"None"** (no necesitamos Kubernetes ni VM)
5. Click **"Create"**

### 3.3 Configurar Aprobaciones

1. Dentro del environment `production-azure`, click en el menú **⋮** (tres puntos)
2. Selecciona **"Approvals and checks"**
3. Click **"+"** → **"Approvals"**
4. Approvers: Añade tu usuario (búscalo por email: `chakootin@gmail.com`)
5. Instructions for approvers: `Revisar cambios de Terraform antes de aplicar a producción`
6. ✅ Marca: **"Allow approvers to approve their own runs"** (para testing)
7. Timeout: `30` days
8. Click **"Create"**

✅ **Completado:** Environment con aprobaciones configurado

---

## 🔑 PASO 4: Configurar Variables del Pipeline

### 4.1 Acceder a Variables

1. **Pipelines** → **Library** (menú izquierdo)
2. Click **"+ Variable group"** (crearemos un grupo de variables)

### 4.2 Crear Variable Group

1. Variable group name: **`TFG-Variables`**
2. Description: `Variables compartidas para el despliegue del TFG`

### 4.3 Añadir Variables (una por una)

Click **"+ Add"** para cada variable:

| Variable Name | Value | Type | Ejemplo |
|---------------|-------|------|---------|
| `TF_VAR_admin_username` | `azureuser` | Normal | Tu usuario actual |
| `TF_VAR_ssh_public_key` | `ssh-rsa AAAAB3Nza...` | Normal | Tu clave pública SSH |
| `TF_VAR_location` | `France Central` | Normal | Región de Azure |
| `TF_VAR_vm_admin_password` | `TuPassword123!` | 🔒 **Secret** | Contraseña segura |
| `TF_VAR_db_password` | `TuDBPassword456!` | 🔒 **Secret** | Contraseña de MySQL |
| `ANSIBLE_USER` | `azureuser` | Normal | Usuario de Ansible |
| `VM_IP_1` | `` | Normal | Se puede dejar vacío |
| `VM_IP_2` | `` | Normal | Se puede dejar vacío |
| `KEYVAULT_URI` | `` | Normal | Se llenará automáticamente |

**Para marcar una variable como secreta:**
- Click en el **candado 🔒** junto al valor
- Esto ocultará el valor en logs

### 4.4 Guardar Variable Group

1. Click **"Save"** (esquina superior)
2. En **"Pipeline permissions"**:
   - Click **"+"** 
   - Selecciona el pipeline que crearás (puedes hacerlo después)
   - O marca: **"Grant access permission to all pipelines"**

✅ **Completado:** Variables configuradas

---

## 📁 PASO 5: Subir Clave SSH como Secure File

### 5.1 Acceder a Secure Files

1. **Pipelines** → **Library**
2. Pestaña: **"Secure files"**

### 5.2 Subir Clave SSH Privada

1. Click **"+ Secure file"** (esquina superior derecha)
2. Click **"Browse"**
3. Selecciona tu archivo: `ansible_id_rsa` (la clave PRIVADA, sin .pub)
   - **Ubicación común:** `~/.ssh/ansible_id_rsa` o `C:\Users\tu_usuario\.ssh\ansible_id_rsa`
4. Click **"Open"** → **"OK"**

### 5.3 Configurar Permisos

1. Click en el archivo `ansible_id_rsa` recién subido
2. En **"Pipeline permissions"**:
   - Click **"+"**
   - O marca: **"Authorize for use in all pipelines"**
3. Click **"Save"**

⚠️ **Importante:** Este archivo NUNCA se debe commitear a Git

✅ **Completado:** Clave SSH segura configurada

---

## 🚀 PASO 6: Crear el Pipeline

### 6.1 Acceder a Pipelines

1. **Pipelines** → **Pipelines** (menú izquierdo)
2. Click **"New pipeline"** (esquina superior derecha)

### 6.2 Seleccionar Repositorio

1. **Where is your code?** → **"Azure Repos Git"**
2. Selecciona: **`TFG_Infraestructura_Segura`**

### 6.3 Configurar Pipeline

1. **Configure your pipeline** → **"Existing Azure Pipelines YAML file"**
2. Branch: **`main`**
3. Path: **`/azure-pipelines.yml`**
4. Click **"Continue"**

### 6.4 Revisar y Ejecutar

1. Se mostrará el contenido de `azure-pipelines.yml`
2. Click en el menú desplegable **"Run"** → **"Save"** (NO ejecutes aún)

### 6.5 Configurar Variables en el Pipeline

1. Click en **"Variables"** (esquina superior derecha)
2. Click **"Variable groups"**
3. **"Link variable group"**
4. Selecciona: **`TFG-Variables`**
5. Click **"Link"**
6. Click **"Save"**

✅ **Completado:** Pipeline creado y vinculado a variables

---

## ✅ PASO 7: Verificación Final - Checklist

Antes de ejecutar, verifica que tienes TODO configurado:

### Service Connection
- [x] Nombre exacto: `Azure-ServiceConnection-TFG`
- [x] Tipo: Azure Resource Manager
- [x] Estado: Ready ✅

### Environment
- [x] Nombre exacto: `production-azure`
- [x] Aprobaciones configuradas
- [x] Tú eres aprobador

### Variables
- [x] Variable group `TFG-Variables` creado
- [x] 9 variables configuradas (5 normales + 4 secretas/opcionales)
- [x] Vinculado al pipeline

### Secure Files
- [x] `ansible_id_rsa` subido
- [x] Permisos otorgados al pipeline

### Extensions
- [x] Terraform extension instalada

---

## 🎯 PASO 8: Primera Ejecución (TEST)

### 8.1 Ejecutar Pipeline

1. Ve a **Pipelines** → **Pipelines**
2. Selecciona tu pipeline (debería llamarse `maikyCS.TFG_Infraestructura_Segura`)
3. Click **"Run pipeline"**
4. Branch: **`main`**
5. Click **"Run"**

### 8.2 Monitorear Ejecución

El pipeline ejecutará en orden:

**Stage 1: Validation** (2-3 min)
- ✅ Security Audit
- ✅ Terraform Validation
- ✅ Ansible Validation

**Stage 2: Terraform Plan** (3-5 min)
- 📋 Genera preview de cambios
- Puedes ver qué recursos se crearán

**Stage 3: Terraform Apply** ⏸️ **ESPERARÁ APROBACIÓN**
- ⚠️ El pipeline se pausará automáticamente
- Recibirás notificación para aprobar
- Click **"Review"** → **"Approve"**
- Solo después aplicará los cambios

**Stage 4: Ansible Deploy** (5-10 min)
- 🔧 Configurará servidores
- 🐳 Desplegará Docker

**Stage 5: Post-Deployment Tests** (1 min)
- ✅ Health check
- 📊 Resumen

### 8.3 Aprobar el Deploy

Cuando llegue al Stage 3:

1. Recibirás email: **"Approval needed for deployment"**
2. O ve a **Pipelines** → tu pipeline → click en el run
3. Verás: **"This pipeline needs permission to access a resource"**
4. Click **"View"** → **"Permit"**
5. Luego verás: **"Waiting for review"**
6. Click **"Review"** → **"Approve"** → Añade comentario opcional → **"Approve"**

### 8.4 Resultado Esperado

Si todo está bien configurado:
- ✅ Todos los stages en verde
- ✅ Infraestructura desplegada en Azure
- ✅ WordPress accesible en la IP del Load Balancer

---

## 🐛 Troubleshooting Comunes

### Error: "Service connection not found"
**Causa:** Nombre incorrecto de Service Connection
**Solución:** Verifica que se llame EXACTAMENTE `Azure-ServiceConnection-TFG`

### Error: "Environment 'production-azure' not found"
**Causa:** Environment no existe o nombre incorrecto
**Solución:** Crea el environment con nombre exacto `production-azure`

### Error: "TerraformInstaller@1 task not found"
**Causa:** Extensión de Terraform no instalada
**Solución:** Instala desde Marketplace como en PASO 1

### Error: "Secure file 'ansible_id_rsa' not found"
**Causa:** Archivo no subido o sin permisos
**Solución:** Sube el archivo y autoriza para todos los pipelines

### Error: "Variable TF_VAR_xxx is not defined"
**Causa:** Variables no configuradas o no vinculadas
**Solución:** Verifica que el Variable Group esté linked al pipeline

### Pipeline se queda en "Queued"
**Causa:** Falta agente disponible
**Solución:** Espera 1-2 minutos. Azure usa agentes compartidos gratuitos

---

## 📚 Recursos Adicionales

**Documentación Oficial:**
- Azure Pipelines: https://docs.microsoft.com/azure/devops/pipelines/
- Terraform Extension: https://marketplace.visualstudio.com/items?itemName=ms-devlabs.custom-terraform-tasks
- Environments: https://docs.microsoft.com/azure/devops/pipelines/process/environments

**Tu Proyecto:**
- Azure DevOps: https://dev.azure.com/maikyCS/TFG_Infraestructura_Segura
- Repositorio: https://dev.azure.com/maikyCS/TFG_Infraestructura_Segura/_git/TFG_Infraestructura_Segura
- Pipelines: https://dev.azure.com/maikyCS/TFG_Infraestructura_Segura/_build

---

## ✅ Checklist Final

Marca cuando completes cada paso:

- [ ] **PASO 1:** Terraform Extension instalada
- [ ] **PASO 2:** Service Connection `Azure-ServiceConnection-TFG` creada
- [ ] **PASO 3:** Environment `production-azure` creado con aprobaciones
- [ ] **PASO 4:** Variable Group `TFG-Variables` con 9 variables
- [ ] **PASO 5:** Secure File `ansible_id_rsa` subido
- [ ] **PASO 6:** Pipeline creado y variables vinculadas
- [ ] **PASO 7:** Verificación completada
- [ ] **PASO 8:** Primera ejecución exitosa

**Cuando tengas todas marcadas, tu Pipeline estará 100% funcional** ✅

---

## 💡 Siguientes Pasos (Opcional)

Una vez que el pipeline funcione:

1. **Configurar Backend de Terraform** (para estado compartido):
   - Crea Storage Account en Azure
   - Configura backend en `terraform/providers.tf`

2. **Notificaciones:**
   - Configura notificaciones a email/Teams/Slack
   - Settings → Notifications → New subscription

3. **Branch Policies:**
   - Require approvals para merge a main
   - Require pipeline success antes de merge

4. **Scheduled Runs:**
   - Ejecutar validation diariamente
   - Detectar drift de Terraform

---

## 🎓 ¡Listo para tu TFG!

Con todos estos pasos completados, tendrás:
- ✅ CI/CD completamente funcional
- ✅ Despliegues automatizados y seguros
- ✅ Aprobaciones manuales para producción
- ✅ Variables y secretos gestionados correctamente
- ✅ Infraestructura reproducible con un click

**¡Éxito con tu presentación!** 🚀
