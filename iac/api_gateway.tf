# HTTP API v2
resource "aws_apigatewayv2_api" "main" {
  name          = "${var.project}-${terraform.workspace}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST"]
    allow_headers = ["Content-Type"]
    max_age       = 300
  }

  tags = {
    Name        = "${var.project}-${terraform.workspace}-api"
    Environment = terraform.workspace
  }
}

# Stage con auto-deploy y logs
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      responseLength = "$context.responseLength"
    })
  }

  default_route_settings {
    throttling_rate_limit  = 10000
    throttling_burst_limit = 5000
  }

  tags = {
    Name        = "${var.project}-${terraform.workspace}-stage"
    Environment = terraform.workspace
  }
}

# Integración con upload-lambda
resource "aws_apigatewayv2_integration" "upload" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.upload.invoke_arn
  payload_format_version = "2.0"
}

# Ruta POST /upload
resource "aws_apigatewayv2_route" "upload" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /upload"
  target    = "integrations/${aws_apigatewayv2_integration.upload.id}"
}

# Permiso para que API Gateway invoque upload-lambda
resource "aws_lambda_permission" "api_upload" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.upload.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}