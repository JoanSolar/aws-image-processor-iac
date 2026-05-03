# Dead Letter Queue
resource "aws_sqs_queue" "dlq" {
  name                      = "${var.project}-${terraform.workspace}-image-dlq"
  message_retention_seconds = 1209600 # 14 días

  tags = {
    Name        = "${var.project}-${terraform.workspace}-image-dlq"
    Environment = terraform.workspace
  }
}

# Cola principal
resource "aws_sqs_queue" "main" {
  name                       = "${var.project}-${terraform.workspace}-image-queue"
  visibility_timeout_seconds = 360  # 6x el timeout de crop-lambda
  message_retention_seconds  = 86400 # 1 día
  receive_wait_time_seconds  = 20   # Long polling

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name        = "${var.project}-${terraform.workspace}-image-queue"
    Environment = terraform.workspace
  }
}

# Política que permite a S3 enviar mensajes a la cola
resource "aws_sqs_queue_policy" "main" {
  queue_url = aws_sqs_queue.main.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.main.arn
        Condition = {
          ArnLike = {
            "aws:SourceArn" = aws_s3_bucket.images.arn
          }
        }
      }
    ]
  })
}