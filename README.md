# FreshBox SpA - Evaluación Parcial 1 ARY1102

Proyecto desarrollado para la asignatura **Arquitectura Cloud (ARY1102)**.

La solución implementa una arquitectura de tres capas en AWS utilizando **Terraform, EC2, Auto Scaling, Docker, Amazon ECR, Application Load Balancer, MariaDB y AWS Backup**.

## Datos del proyecto

**Estudiante:** Lucía Villalobos  
**Asignatura:** ARY1102 — Arquitectura Cloud  
**Evaluación:** Evaluación Parcial 1  
**Caso:** FreshBox SpA — Catálogo Online de Productos Orgánicos

---

## Arquitectura

La infraestructura se despliega en:

`us-east-1`

La VPC utiliza:

`10.0.0.0/22`

La arquitectura está compuesta por:

- 2 subredes públicas para el Application Load Balancer.
- 2 subredes privadas APP distribuidas entre `us-east-1a` y `us-east-1b`.
- 2 subredes privadas DATA distribuidas entre `us-east-1a` y `us-east-1b`.
- Internet Gateway.
- NAT Gateway ubicado en una subred pública.
- Application Load Balancer público.
- Auto Scaling Group para la capa APP.
- Mínimo 2, deseado 2 y máximo 4 instancias APP.
- Distribución de APP entre dos zonas de disponibilidad.
- 5 repositorios Amazon ECR.
- MariaDB PRIMARY en DATA-1A.
- MariaDB SECONDARY en DATA-1B.
- Replicación PRIMARY → SECONDARY.
- AWS Backup para la base de datos.

Las instancias EC2 utilizan arquitectura **ARM64 (AWS Graviton)**.

---

## Microservicios

| Servicio | Puerto |
| --- | ---: |
| Frontend | 80 |
| GET Products | 3001 |
| CREATE Product | 3002 |
| UPDATE Product | 3003 |
| DELETE Product | 3004 |

---

## Requisitos

Para realizar el despliegue se requiere:

- AWS Academy Learner Lab iniciado.
- Credenciales temporales AWS configuradas.
- AWS CLI.
- Terraform.
- Docker Desktop iniciado.
- Docker Buildx.
- Git.
- Git Bash en Windows para ejecutar scripts `.sh`.

> El proyecto utiliza los roles disponibles en AWS Academy Learner Lab.

---

## Seguridad de credenciales

Las contraseñas de MariaDB no se almacenan directamente en el código fuente ni se publican en GitHub.

El repositorio incluye:

`terraform.tfvars.example`

Antes de desplegar, se debe crear una copia llamada:

`terraform.tfvars`

Ejemplo:

```hcl
db_password          = "PASSWORD_SEGURO"
replication_password = "PASSWORD_REPLICACION_SEGURO"
```

El archivo `terraform.tfvars` está excluido mediante `.gitignore` y no debe subirse al repositorio.

Terraform utiliza estas variables para configurar:

- El usuario de aplicación de MariaDB.
- El usuario de replicación PRIMARY–SECONDARY.
- Los microservicios desplegados en las instancias APP.
- La configuración inicial de la replicación.

---

# Despliegue

## 1. Clonar el repositorio

```bash
git clone https://github.com/luciaV1982/EP1-ARY1102-FreshBox-Luc-a-Villalobos.git
cd EP1-ARY1102-FreshBox-Luc-a-Villalobos
```

---

## 2. Validar credenciales AWS

Con AWS Academy Learner Lab iniciado y las credenciales temporales configuradas:

```bash
aws sts get-caller-identity
```

El comando debe mostrar la cuenta correspondiente al laboratorio AWS activo.

---

## 3. Configurar variables de base de datos

En PowerShell:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

Editar `terraform.tfvars` y reemplazar los valores de ejemplo por contraseñas seguras.

> `terraform.tfvars` está excluido de Git y no debe publicarse.

---

## 4. Inicializar y validar Terraform

```bash
terraform init
terraform fmt -recursive
terraform validate
terraform plan
```

La validación correcta debe mostrar:

```text
Success! The configuration is valid.
```

---

## 5. Desplegar FreshBox

Antes de ejecutar Terraform, verificar que **Docker Desktop esté iniciado**.

Ejecutar:

```bash
terraform apply
```

Confirmar escribiendo:

```text
yes
```

El despliegue automatiza la creación y configuración de la infraestructura.

Durante el proceso Terraform:

1. Crea la infraestructura de red.
2. Crea los Security Groups.
3. Crea los repositorios Amazon ECR.
4. Ejecuta automáticamente `app/scripts/ecr-push.sh`.
5. Construye las 5 imágenes Docker para arquitectura `linux/arm64`.
6. Publica las imágenes en Amazon ECR.
7. Configura MariaDB PRIMARY y SECONDARY.
8. Configura la replicación PRIMARY → SECONDARY.
9. Crea el Launch Template y Auto Scaling Group.
10. Las instancias APP descargan las imágenes y levantan automáticamente los contenedores.
11. El Application Load Balancer distribuye las solicitudes entre las instancias saludables.

Por lo tanto, **no es necesario ejecutar manualmente `ecr-push.sh` después del `terraform apply`**.

---

## 6. Outputs

Al finalizar:

```bash
terraform output
```

Los principales outputs son:

- `alb_dns`
- `freshbox_url`
- `autoscaling_group_name`
- `mysql_private_ip`

Para obtener directamente la URL:

```bash
terraform output -raw freshbox_url
```

Abrir la dirección obtenida en el navegador.

---

# Automatización de imágenes Docker y Amazon ECR

Terraform crea los repositorios:

- `freshbox-frontend`
- `freshbox-get-products`
- `freshbox-create-product`
- `freshbox-update-product`
- `freshbox-delete-product`

El recurso de automatización definido en Terraform ejecuta:

```text
app/scripts/ecr-push.sh
```

El script:

1. Obtiene el ID de la cuenta AWS.
2. Inicia sesión en Amazon ECR.
3. Utiliza Docker Buildx.
4. Construye imágenes para `linux/arm64`.
5. Publica las 5 imágenes con la etiqueta `latest`.

El Auto Scaling Group depende de la finalización de este proceso, evitando que las instancias APP sean creadas antes de que las imágenes estén disponibles en ECR.

---

# Capa APP y Auto Scaling

La capa de aplicación utiliza un **Launch Template y Auto Scaling Group (ASG)**.

Configuración:

- Mínimo: 2 instancias.
- Deseado: 2 instancias.
- Máximo: 4 instancias.
- Distribución entre `us-east-1a` y `us-east-1b`.
- Integración con el Target Group del Application Load Balancer.

El Auto Scaling Group utiliza la última versión del Launch Template (`$Latest`) y tiene configurado `instance_refresh` con estrategia `Rolling`. De esta forma, cuando Terraform actualiza el Launch Template, las instancias APP pueden renovarse progresivamente para utilizar la nueva configuración sin reemplazarlas todas al mismo tiempo.

Las nuevas instancias ejecutan automáticamente el `user_data` configurado mediante Terraform.

Durante el arranque se prepara y ejecuta:

```text
/home/ec2-user/deploy-containers.sh
```

El script descarga las imágenes desde Amazon ECR y levanta los cinco contenedores de FreshBox.

Esto permite que las nuevas instancias creadas por el Auto Scaling Group queden preparadas automáticamente para formar parte de la capa APP.

---

## Validar los contenedores

Ingresar a una instancia APP mediante **AWS Systems Manager → Session Manager**.

Ejecutar:

```bash
sudo docker ps
```

Deben aparecer:

- `freshbox-frontend`
- `freshbox-get-products`
- `freshbox-create-product`
- `freshbox-update-product`
- `freshbox-delete-product`

También puede revisarse la inicialización mediante:

```bash
sudo cat /var/log/user-data.log
```

---

# Validación de FreshBox

## Application Load Balancer

Obtener la URL:

```bash
terraform output -raw freshbox_url
```

Abrirla en el navegador.

La API puede validarse mediante:

```bash
curl "$(terraform output -raw freshbox_url)/api/products"
```

El Target Group debe mostrar las instancias activas del Auto Scaling Group en estado **Healthy**.

## CRUD

Desde la interfaz web se validan las operaciones:

- Listar productos.
- Crear producto.
- Modificar producto.
- Eliminar producto.

Flujo principal:

`Internet → ALB → ASG/EC2 APP → Microservicios Docker → MariaDB PRIMARY`

---

# Seguridad

La comunicación está segmentada mediante Security Groups.

### SG-ALB

Permite:

- TCP 80 desde Internet.
- TCP 443 desde Internet.

### SG-APP

Permite desde `SG-ALB`:

- TCP 80.
- TCP 3001-3004.

### SG-DATA

Permite:

- TCP 3306 desde `SG-APP`.
- TCP 3306 entre servidores pertenecientes al mismo `SG-DATA` para la replicación MariaDB.

Las instancias APP y DATA se encuentran en subredes privadas.

Los volúmenes EBS están cifrados.

Las credenciales de MariaDB se reciben mediante variables sensibles de Terraform y no se almacenan directamente en el código fuente del repositorio.

---

# Base de datos y replicación

La capa DATA utiliza dos instancias EC2 con MariaDB distribuidas entre dos zonas de disponibilidad.

### PRIMARY

- Ubicada en DATA-1A / `us-east-1a`.
- `server_id=1`.
- Binary Log habilitado.
- Base de datos `freshbox`.
- Recibe las operaciones utilizadas por la aplicación.

### SECONDARY

- Ubicada en DATA-1B / `us-east-1b`.
- `server_id=2`.
- Configurada como `read_only`.
- Recibe los cambios mediante replicación desde PRIMARY.

El script:

```text
scripts/configure-replication.sh
```

automatiza la configuración de replicación durante un nuevo despliegue.

Para comprobar su estado:

```sql
SHOW SLAVE STATUS\G
```

Los valores esperados son:

```text
Slave_IO_Running: Yes
Slave_SQL_Running: Yes
Seconds_Behind_Master: 0
```

---

## Validación de replicación

La replicación fue comprobada realizando operaciones sobre PRIMARY y verificando su sincronización en SECONDARY.

Esto permite validar la comunicación y replicación entre ambas instancias ubicadas en zonas de disponibilidad diferentes.

---

## Failover manual/controlado

También se validó un procedimiento de **failover manual/controlado**.

El procedimiento consiste en:

1. Verificar que SECONDARY esté sincronizada.
2. Detener MariaDB en PRIMARY.
3. Detener temporalmente la replicación en SECONDARY.
4. Desactivar `read_only` en SECONDARY.
5. Validar que SECONDARY pueda aceptar escrituras.
6. Restaurar PRIMARY.
7. Volver a activar `read_only` en SECONDARY.
8. Reiniciar la replicación.

Posteriormente se verifica nuevamente:

```text
Slave_IO_Running: Yes
Slave_SQL_Running: Yes
Seconds_Behind_Master: 0
```

> Esta implementación demuestra replicación entre zonas de disponibilidad y un procedimiento de failover manual/controlado. No corresponde a un mecanismo de failover automático de la base de datos.

---

# AWS Backup

Terraform configura AWS Backup para proteger la base de datos.

Configuración:

- Backup diario.
- Ejecución programada a las 05:00 UTC.
- Retención de 7 días.
- Backup Vault dedicado para FreshBox.

---

# Alta disponibilidad y escalabilidad

### Capa APP

El Auto Scaling Group mantiene al menos dos instancias distribuidas entre dos zonas de disponibilidad.

El Application Load Balancer distribuye las solicitudes entre las instancias saludables.

Si una instancia APP deja de estar disponible, el Auto Scaling Group puede reemplazarla para recuperar la capacidad deseada.

### Capa DATA

PRIMARY y SECONDARY están distribuidas entre `us-east-1a` y `us-east-1b`.

La replicación mantiene una copia secundaria de la información y se validó un procedimiento de failover manual/controlado.

---

# Estructura del proyecto

```text
FreshBox-Terraform/
|
|-- providers.tf
|-- variables.tf
|-- network.tf
|-- security.tf
|-- compute.tf
|-- ecr.tf
|-- alb.tf
|-- backup.tf
|-- outputs.tf
|-- init.sql
|-- terraform.tfvars.example
|-- README.md
|
|-- scripts/
|   `-- configure-replication.sh
|
`-- app/
    |-- microservicioFrontend/
    |-- microserviciosBackend/
    |   |-- get-products/
    |   |-- create-product/
    |   |-- update-product/
    |   `-- delete-product/
    |
    `-- scripts/
        |-- ecr-push.sh
        `-- deploy-containers.sh
```

> `terraform.tfvars` no aparece en la estructura versionada porque está excluido mediante `.gitignore`.

---

## Integración Continua con GitHub Actions

El proyecto incorpora una pipeline de **Integración Continua (CI)** mediante GitHub Actions.

Cada vez que se realiza un `push` o `pull request` hacia la rama `main`, la pipeline ejecuta automáticamente:

1. Verificación del formato de Terraform (`terraform fmt`).
2. Inicialización de Terraform (`terraform init`).
3. Validación de la configuración (`terraform validate`).
4. Análisis de seguridad de la infraestructura como código mediante **Checkov**.

Checkov reporta posibles mejoras de seguridad sin bloquear la ejecución de la pipeline (`soft_fail: true`).

La pipeline no ejecuta `terraform apply`, por lo que no realiza cambios automáticos sobre la infraestructura de AWS Academy.

Archivo de configuración:

`.github/workflows/terraform-ci.yml`

# Eliminación de la infraestructura

Para eliminar los recursos:

```bash
terraform destroy
```

Confirmar:

```text
yes
```

Los repositorios Amazon ECR utilizan `force_delete = true`, permitiendo su eliminación aunque contengan imágenes.

> Si AWS Backup ha generado puntos de recuperación, estos pueden requerir limpieza antes de eliminar el Backup Vault.

---

## Proyecto académico

**Evaluación Parcial 1 — ARY1102 Arquitectura Cloud**

**Caso:** FreshBox SpA — Catálogo Online de Productos Orgánicos

**Estudiante:** Lucía Villalobos
