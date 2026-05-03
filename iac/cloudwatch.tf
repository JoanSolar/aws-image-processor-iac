# Log Group para upload-lambda
resource "aws_cloudwatch_log_group" "upload_lambda" {
  name              = "/aws/lambda/${var.project}-${terraform.workspace}-upload"
  retention_in_days = 14

  tags = {
    Name        = "${var.project}-${terraform.workspace}-upload-logs"
    Environment = terraform.workspace
  }
}

# Log Group para crop-lambda
resource "aws_cloudwatch_log_group" "crop_lambda" {
  name              = "/aws/lambda/${var.project}-${terraform.workspace}-crop"
  retention_in_days = 14

  tags = {
    Name        = "${var.project}-${terraform.workspace}-crop-logs"
    Environment = terraform.workspace
  }
}

# Log Group para API Gateway
resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.project}-${terraform.workspace}"
  retention_in_days = 14

  tags = {
    Name        = "${var.project}-${terraform.workspace}-api-logs"
    Environment = terraform.workspace
  }
}

# SNS Topic para notificaciones de alarma
resource "aws_sns_topic" "alarm" {
  name = "${var.project}-${terraform.workspace}-alarm-topic"

  tags = {
    Name        = "${var.project}-${terraform.workspace}-alarm-topic"
    Environment = terraform.workspace
  }
}

# Suscripción al SNS Topic con el correo configurado
resource "aws_sns_topic_subscription" "alarm_email" {
  topic_arn = aws_sns_topic.alarm.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Alarma cuando la DLQ tiene mensajes visibles
resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  alarm_name          = "${var.project}-${terraform.workspace}-dlq-messages-alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Hay mensajes en la DLQ que fallaron 3 veces"

  dimensions = {
    QueueName = aws_sqs_queue.dlq.name
  }

  alarm_actions = [aws_sns_topic.alarm.arn]

  tags = {
    Name        = "${var.project}-${terraform.workspace}-dlq-alarm"
    Environment = terraform.workspace
  }
}