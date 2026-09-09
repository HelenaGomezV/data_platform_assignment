

# Exercise 2 — Terraform

## Descripción

Este ejercicio gestiona el usuario de servicio `SVC_AIRBYTE` en Snowflake y los recursos necesarios para el workload de ingestion.

El diseño asume que los cambios de producción se gestionan desde un único repositorio Terraform y se aplican mediante CI. Los desarrolladores no aplican cambios de producción directamente desde sus laptops.

Los principales recursos gestionados en este ejercicio son:

- `SVC_AIRBYTE`: usuario de servicio de Snowflake.
- `ROLE_INGESTION`: rol de Snowflake que ya existe y que se asigna al usuario.
- `WH_INGESTION`: warehouse dedicado al workload de ingestion.
- Par de claves RSA: utilizado para autenticación mediante key pair.
- AWS Secrets Manager: almacena el material de las claves.

No es necesario disponer de una cuenta real de AWS o Snowflake para este ejercicio.

---

## 1. Providers y autenticación

Las versiones de los providers de Terraform están fijadas en `versions.tf`.

Se utilizan los siguientes providers:

- AWS
- Snowflake
- TLS

El lock file de Terraform está versionado en el repositorio para asegurar que CI y los entornos de desarrollo utilizan las mismas versiones de providers.

### AWS

Para producción utilizaría GitHub Actions OIDC para obtener credenciales temporales de AWS mediante `AssumeRole`.

Esto evita almacenar claves de acceso AWS de larga duración en GitHub Secrets.

El IAM Role utilizado por CI tendría únicamente los permisos necesarios para gestionar los recursos de este repositorio.

Los desarrolladores no deberían necesitar credenciales de producción de AWS en sus laptops.

### Snowflake

Terraform debería autenticarse en Snowflake utilizando una identidad dedicada a CI con los mínimos privilegios necesarios para gestionar los recursos de este repositorio.

No utilizaría `ACCOUNTADMIN` durante la operación normal.

Las credenciales de producción no deben almacenarse en el repositorio ni pasarse como variables Terraform en texto plano.

### Desarrollo

El entorno de desarrollo utilizaría una cuenta/proyecto de AWS y un entorno de Snowflake separados de producción, con un Terraform state independiente.

Las credenciales y el state de producción no deberían utilizarse desde un entorno local de desarrollo.

---

## 2. Adopción de SVC_AIRBYTE

`SVC_AIRBYTE` fue creado manualmente en la interfaz de Snowflake durante un incidente y lleva funcionando en producción desde entonces.

Los siguientes tres recursos AWS ya existen y ya están gestionados por Terraform:

```text
tls_private_key.svc_airbyte
aws_secretsmanager_secret.svc_airbyte
aws_secretsmanager_secret_version.svc_airbyte
```
El par de claves está actualmente en uso en producción, por lo que no debe ser recreado ni rotado como parte de este refactor.

El usuario SVC_AIRBYTE existe en Snowflake, pero fue creado manualmente y todavía no está representado en el Terraform state.

Por tanto, la adopción distingue entre:
* Recursos que ya están en Terraform state.
* Recursos que existen fuera del Terraform state.

### 2.1 Mover los recursos AWS existentes al módulo

Como los tres recursos AWS ya están gestionados por Terraform, utilizaría terraform state mv en lugar de importarlos o recrearlos.

Los comandos serían:

```bash
terraform state mv \
  tls_private_key.svc_airbyte \
  module.svc_airbyte.tls_private_key.this

terraform state mv \
  aws_secretsmanager_secret.svc_airbyte \
  module.svc_airbyte.aws_secretsmanager_secret.this

terraform state mv \
  aws_secretsmanager_secret_version.svc_airbyte \
  module.svc_airbyte.aws_secretsmanager_secret_version.this
```
terraform ```bash state mv ```cambia la dirección del recurso dentro del Terraform state, pero no mueve ni recrea el recurso real en AWS.

```bash
Antes:

Terraform State
└── tls_private_key.svc_airbyte
          |
          └──> clave existente en producción


Después:

Terraform State
└── module.svc_airbyte.tls_private_key.this
          |
          └──> misma clave existente en producción
```

Esto es especialmente importante porque la clave está siendo utilizada por un servicio en producción. Una recreación o rotación accidental podría interrumpir la autenticación del servicio.

### 2.2 Importar el usuario de Snowflake

El usuario SVC_AIRBYTE ya existe en Snowflake, pero no está en Terraform state.

Por tanto, se importa en la dirección correspondiente al módulo:

```bash
terraform import \
  module.svc_airbyte.snowflake_service_user.this \
  SVC_AIRBYTE
```

El objetivo del import es asociar el usuario existente con el recurso Terraform, no crear un segundo usuario.

### 2.3 Comprobar el plan antes de aplicar

Después de mover los recursos AWS e importar el usuario de Snowflake, ejecutaría:

```bash
terraform plan
```

El plan debe revisarse antes de cualquier aplicación en producción.

Los recursos existentes, especialmente la clave, el secret y la secret version, no deben aparecer como reemplazados o destruidos.

El resultado esperado una vez que el state y la configuración estén alineados sería:

```bash
Plan: 0 to add, 0 to change, 0 to destroy.
```
## 3. Módulo de usuario de servicio

El módulo service_user gestiona de extremo a extremo los recursos relacionados con el usuario de servicio:

* Par de claves RSA.
* AWS Secrets Manager secret.
* AWS Secrets Manager secret version.
* Usuario de servicio de Snowflake.
* Asignación del role.

La relación entre estos recursos es:

```bash
                tls_private_key
                       |
             +---------+---------+
             |                   |
             v                   v
       private key          public key
             |                   |
             v                   v
    AWS Secrets Manager     SVC_AIRBYTE
                                  |
                                  v
                           ROLE_INGESTION
```

La misma clave pública que pertenece al par de claves gestionado por Terraform se utiliza para la autenticación del usuario en Snowflake.

El usuario de Snowflake se configura con:

```bash
default_role      = ROLE_INGESTION
default_warehouse = WH_INGESTION
rsa_public_key    = public key del par de claves gestionado
```
La clave pública se transforma al formato requerido por Snowflake, es decir, una única línea sin las cabeceras y trailers PEM.

De esta forma no mantenemos dos fuentes de verdad diferentes para la clave pública.

## 4. Warehouse de ingestion

Se crea un warehouse dedicado para el workload de ingestion:
```bash
WH_INGESTION

Tamaño:              XSMALL
Auto-suspend:        60 segundos
Auto-resume:         true
Initially suspended: true
```
## Decisión de tamaño y coste
Empezaría con un warehouse XSMALL porque el assignment no proporciona evidencia de que el workload de ingestion necesite más capacidad de compute.

Empezar pequeño evita sobreaprovisionar y permite establecer una línea base de rendimiento y coste.

Después monitorizaría la duración de los procesos y posibles esperas (queueing). Si el workload demuestra que necesita más capacidad, aumentaría el tamaño basándome en métricas reales.

AUTO_SUSPEND evita consumir compute cuando el warehouse está inactivo y AUTO_RESUME permite que vuelva a iniciarse cuando llega nuevo trabajo.

INITIALLY_SUSPENDED = true evita que el warehouse empiece consumiendo compute inmediatamente después de su creación.

## 5. Hacer que SVC_AIRBYTE utilice el warehouse

SVC_AIRBYTE utiliza:

```bash
default_warehouse = WH_INGESTION
```
Además, ROLE_INGESTION recibe el privilegio USAGE sobre el warehouse.

La relación final es:

```bash
SVC_AIRBYTE
     |
     | default_role
     v
ROLE_INGESTION
     |
     | USAGE
     v
WH_INGESTION
```
### 6. Least privilege

SVC_AIRBYTE es una identidad de servicio y debe tener únicamente los permisos necesarios para realizar ingestion.

El límite conceptual de acceso es:
```bash
SVC_AIRBYTE
     |
     v
ROLE_INGESTION
     |
     +----> WH_INGESTION
     |
     +----> BRONZE
```
El servicio de ingestion no debería recibir acceso a SILVER o GOLD.

ROLE_INGESTION se considera un role existente gestionado fuera de este módulo. Este módulo se encarga de asignarlo al service user.

Esto mantiene una separación clara entre:

* Gestión de la identidad del servicio.
* Permisos del role sobre los datos.

### 7. CI/CD

Todo el Terraform de producción debe ejecutarse desde CI.

Ningún desarrollador debería ejecutar un terraform apply de producción desde su laptop.

#### Pull Request

En cada Pull Request ejecutaría como mínimo:

* terraform fmt -check
* terraform init
* terraform validate
* terraform plan

El plan debería estar disponible para revisión antes del merge.

El objetivo del workflow de Pull Request es detectar:

* Problemas de formato.
* Errores de configuración.
* Problemas con providers.
* Cambios inesperados en infraestructura.
* Posibles replacements o destroys.
* Merge a producción

Después del merge a la rama de producción, GitHub Actions ejecutaría Terraform utilizando:

* Las credenciales de CI.
* El Terraform state de producción.
* Las versiones fijadas de los providers.

El apply se ejecutaría desde CI y no desde un ordenador personal.