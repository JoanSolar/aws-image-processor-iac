# aws-image-processor-iac

Infraestructura como código (IaC) para un sistema serverless de procesamiento de imágenes en AWS. Permite subir imágenes mediante una API HTTP, las almacena en S3 y las procesa automáticamente recortándolas en formato circular de 40x40 px PNG.

## Arquitectura

## Requisitos previos

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.5.0
- [AWS CLI](https://aws.amazon.com/cli/) v2 configurado con credenciales válidas
- [Node.js](https://nodejs.org/) >= 18.x
- Cuenta de AWS activa con tarjeta registrada

## Instalación y configuración

### 1. Clonar el repositorio

```bash
git clone https://github.com/JoanSolar/aws-image-processor-iac.git
cd aws-image-processor-iac
```

### 2. Instalar dependencias de las Lambdas

```bash
cd src/upload-lambda
npm install
cd ../crop-lambda
npm install
cd ../../iac
```

### 4. Inicializar Terraform

```bash
cd iac
terraform init
```

## Despliegue por entorno

### DEV

```bash
terraform workspace new dev
terraform workspace select dev
terraform apply -var-file="dev.tfvars"
```

### QA

```bash
terraform workspace new qa
terraform workspace select qa
terraform apply -var-file="qa.tfvars"
```

### PROD

```bash
terraform workspace new prod
terraform workspace select prod
terraform apply -var-file="prod.tfvars"
```

Al finalizar cada despliegue, Terraform mostrará el endpoint:

```bash
terraform output api_endpoint
```

## Uso de la API

### Subir una imagen (multipart/form-data)

```bash
curl -X POST https://<api-endpoint>/upload \
  -F "file=@C:\Users\Joan\aws_image_processor_iac\aws-image-processor-iac\perfill.jpg"
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

### Resultado esperado

```json
{ "message": "Imagen subida correctamente", "key": "uploads/uuid.jpg" }
```

Luego de unos segundos, la imagen procesada aparece en `processed/` del bucket S3 como `uuid_circular.png` — un PNG de 40x40 px con recorte circular transparente.

## Destruir recursos

⚠️ Antes de destruir, vaciar el bucket S3 de cada entorno:

```bash
aws s3 rm s3://image-processor-<env>-images-<account_id> --recursive
aws s3api list-object-versions --bucket image-processor-<env>-images-<account_id> \
  --query "{Objects: Versions[].{Key:Key,VersionId:VersionId}}" \
  --output json > versions.json
aws s3api delete-objects --bucket image-processor-<env>-images-<account_id> \
  --delete file://versions.json
```

Luego destruir:

```bash
terraform workspace select <env>
terraform destroy -var-file="<env>.tfvars"
```

Repetir para dev, qa y prod.

## Entornos

| Entorno | Workspace | Bucket                                   |
| ------- | --------- | ---------------------------------------- |
| DEV     | dev       | image-processor-dev-images-{account_id}  |
| QA      | qa        | image-processor-qa-images-{account_id}   |
| PROD    | prod      | image-processor-prod-images-{account_id} |

## Endpoints desplegados

| Entorno | URL                                                    |
| ------- | ------------------------------------------------------ |
| DEV     | https://rgku54yv1e.execute-api.us-east-1.amazonaws.com |
| QA      | https://8d6eg9kw0e.execute-api.us-east-1.amazonaws.com |
| PROD    | https://j8mu3qe60g.execute-api.us-east-1.amazonaws.com |

## Convenciones de commits

Este proyecto usa [Conventional Commits](https://www.conventionalcommits.org/):

- `feat`: nueva funcionalidad
- `fix`: corrección de errores
- `chore`: tareas de configuración y mantenimiento
- `docs`: documentación
