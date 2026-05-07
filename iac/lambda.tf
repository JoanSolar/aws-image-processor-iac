# Zip de upload-lambda
data "archive_file" "upload_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../src/upload-lambda"
  output_path = "${path.module}/../src/upload-lambda/upload-lambda.zip"
}

# Zip de crop-lambda
data "archive_file" "crop_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/../src/crop-lambda"
  output_path = "${path.module}/../src/crop-lambda/crop-lambda.zip"
}

# Función upload-lambda
resource "aws_lambda_function" "upload" {
  function_name    = "${var.project}-${terraform.workspace}-upload"
  role             = aws_iam_role.upload_lambda.arn
  runtime          = "nodejs20.x"
  handler          = "index.handler"
  filename         = data.archive_file.upload_lambda.output_path
  source_code_hash = data.archive_file.upload_lambda.output_base64sha256
  memory_size      = 256
  timeout          = 30

  environment {
    variables = {
      S3_BUCKET     = aws_s3_bucket.images.bucket
      UPLOAD_PREFIX = "uploads/"
    }
  }

  vpc_config {
    subnet_ids = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id
    ]
    security_group_ids = [aws_security_group.upload_lambda.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.upload_basic,
    aws_iam_role_policy_attachment.upload_vpc,
    aws_cloudwatch_log_group.upload_lambda
  ]

  tags = {
    Name        = "${var.project}-${terraform.workspace}-upload"
    Environment = terraform.workspace
  }
}

# Función crop-lambda
resource "aws_lambda_function" "crop" {
  function_name    = "${var.project}-${terraform.workspace}-crop"
  role             = aws_iam_role.crop_lambda.arn
  runtime          = "nodejs20.x"
  handler          = "index.handler"
  filename         = data.archive_file.crop_lambda.output_path
  source_code_hash = data.archive_file.crop_lambda.output_base64sha256
  memory_size      = 512
  timeout          = 60

  environment {
    variables = {
      S3_BUCKET        = aws_s3_bucket.images.bucket
      PROCESSED_PREFIX = "processed/"
    }
  }

  vpc_config {
    subnet_ids = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id
    ]
    security_group_ids = [aws_security_group.crop_lambda.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.crop_basic,
    aws_iam_role_policy_attachment.crop_vpc,
    aws_cloudwatch_log_group.crop_lambda
  ]

  tags = {
    Name        = "${var.project}-${terraform.workspace}-crop"
    Environment = terraform.workspace
  }
}

# Trigger: SQS → crop-lambda
resource "aws_lambda_event_source_mapping" "sqs_crop" {
  event_source_arn        = aws_sqs_queue.main.arn
  function_name           = aws_lambda_function.crop.arn
  batch_size              = 5
  function_response_types = ["ReportBatchItemFailures"]
}
