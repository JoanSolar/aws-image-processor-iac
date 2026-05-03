# Security Group para upload-lambda
resource "aws_security_group" "upload_lambda" {
  name        = "sg-upload-lambda-${terraform.workspace}"
  description = "SG for upload lambda - no inbound, outbound 443 only"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "HTTPS to VPC endpoints"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "sg-upload-lambda-${terraform.workspace}"
    Environment = terraform.workspace
  }
}

# Security Group para crop-lambda
resource "aws_security_group" "crop_lambda" {
  name        = "sg-crop-lambda-${terraform.workspace}"
  description = "SG for crop lambda - no inbound, outbound 443 only"
  vpc_id      = aws_vpc.main.id

  egress {
    description = "HTTPS to VPC endpoints"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "sg-crop-lambda-${terraform.workspace}"
    Environment = terraform.workspace
  }
}

# Security Group para VPC Endpoint de SQS
resource "aws_security_group" "vpce_sqs" {
  name        = "sg-vpce-sqs-${terraform.workspace}"
  description = "SG for SQS VPC endpoint"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTPS from upload-lambda"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.upload_lambda.id]
  }

  ingress {
    description     = "HTTPS from crop-lambda"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.crop_lambda.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "sg-vpce-sqs-${terraform.workspace}"
    Environment = terraform.workspace
  }
}