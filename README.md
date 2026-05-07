# aws-image-processor-iac

Infraestructura como código (IaC) para un sistema serverless de procesamiento de imágenes en AWS. Permite subir imágenes mediante una API HTTP, las almacena en S3 y las procesa automáticamente recortándolas en formato circular de 40x40 px.

## Arquitectura

### Componentes

- **API Gateway HTTP API v2** — Endpoint HTTPS para recibir imágenes (POST /upload)
- **upload-lambda** — Recibe la imagen y la sube a S3
- **S3 Bucket** — Almacena imágenes originales (uploads/) y procesadas (processed/)
- **SQS Queue + DLQ** — Cola de mensajes para procesamiento asíncrono
- **crop-lambda** — Descarga, recorta en círculo 40x40 PNG y sube a processed/
- **VPC** — Red privada con subnets públicas y privadas en 2 zonas de disponibilidad
- **NAT Gateways** — Permiten salida a internet desde subnets privadas
- **VPC Endpoints** — S3 (Gateway) y SQS (Interface) para tráfico interno
- **IAM** — Roles con mínimo privilegio para cada Lambda
- **CloudWatch** — Log groups, alarma en DLQ y notificaciones por SNS

## Requisitos

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.5.0
- [AWS CLI](https://aws.amazon.com/cli/) configurado con credenciales válidas
- [Node.js](https://nodejs.org/) >= 18.x
- Cuenta de AWS activa

## Estructura del proyecto

```text
aws-image-processor-iac/
├── iac/                     # Código Terraform
│   ├── main.tf              # Recursos principales
│   ├── variables.tf         # Variables
│   ├── outputs.tf           # Outputs
│   ├── backend.tf           # Configuración de backend
│   ├── provider.tf          # Proveedor AWS
│   ├── vpc.tf               # Redes VPC
│   ├── s3.tf                # S3 bucket + notificaciones
│   ├── sqs.tf               # SQS queue + DLQ
│   ├── iam.tf               # Roles y políticas IAM
│   ├── lambda.tf            # Lambdas (upload + crop)
│   ├── api_gateway.tf       # API Gateway HTTP API
│   ├── cloudwatch.tf        # Logs, alarmas, SNS
│   └── dev.tfvars           # Variables entorno desarrollo
│   └── qa.tfvars            # Variables entorno QA
│   └── prod.tfvars          # Variables entorno producción
├── lambda/                  # Código Lambda
│   ├── upload-lambda/       # Lambda para subir imagen
│   │   ├── index.js         # Lógica
│   │   └── package.json
│   └── crop-lambda/         # Lambda para recortar
│       ├── index.js         # Lógica + sharp
│       ├── package.json
│       └── sharp.zip        # Bundle con Sharp
├── terraform-lambda-layer/  # Layer con Sharp
│   └── nodejs/              # Estructura del layer
├── Dockerfile               # Docker para crear sharp.zip
└── README.md                # Documentación
```

## Despliegue

### 1. Clonar el repositorio

```bash
git clone https://github.com/tu-usuario/aws-image-processor-iac.git
cd aws-image-processor-iac
```

### 2. Configurar AWS CLI

```bash
aws configure
```

### 3. Inicializar Terraform

```bash
cd iac
terraform init
```

### 4. Desplegar por entorno

#### DEV

```bash
terraform workspace new dev
terraform workspace select dev
terraform apply -var-file="dev.tfvars"
```

#### QA

```bash
terraform workspace new qa
terraform workspace select qa
terraform apply -var-file="qa.tfvars"
```

#### PROD

```bash
terraform workspace new prod
terraform workspace select prod
terraform apply -var-file="prod.tfvars"
```

### 5. Obtener el endpoint de la API

Al finalizar el despliegue, Terraform mostrará el endpoint:

```bash
terraform output api_endpoint
```

## Uso de la API

### Subir una imagen (multipart/form-data)

```bash
curl -X POST https://<api-endpoint>/upload \
  -F "file=@imagen.jpg"
```

### Subir una imagen (JSON + base64)

```bash
curl -X POST https://<api-endpoint>/upload \
  -H "Content-Type: application/json" \
  -d '{"image": "<base64>", "mimeType": "image/jpeg"}'
```

### Restricciones

- Tamaño máximo: 10 MB
- Formatos permitidos: jpg, png, gif, webp

## Destruir recursos

```bash
terraform workspace select dev
terraform destroy -var-file="dev.tfvars"

terraform workspace select qa
terraform destroy -var-file="qa.tfvars"

terraform workspace select prod
terraform destroy -var-file="prod.tfvars"
```

## Entornos y puertos

| Entorno | Workspace | Bucket                                   |
| ------- | --------- | ---------------------------------------- |
| DEV     | dev       | image-processor-dev-images-{account_id}  |
| QA      | qa        | image-processor-qa-images-{account_id}   |
| PROD    | prod      | image-processor-prod-images-{account_id} |

## Convenciones de commits

Este proyecto usa [Conventional Commits](https://www.conventionalcommits.org/):

- `feat`: nueva funcionalidad
- `fix`: corrección de errores
- `chore`: tareas de configuración
- `docs`: documentación
