data "aws_caller_identity" "current" {}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name        = "${var.project}-${terraform.workspace}-vpc"
    Environment = terraform.workspace
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project}-${terraform.workspace}-igw"
    Environment = terraform.workspace
  }
}

# Public Subnet AZ-a
resource "aws_subnet" "public_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.region}a"

  tags = {
    Name        = "${var.project}-${terraform.workspace}-pub-a"
    Environment = terraform.workspace
  }
}

# Public Subnet AZ-b
resource "aws_subnet" "public_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "${var.region}b"

  tags = {
    Name        = "${var.project}-${terraform.workspace}-pub-b"
    Environment = terraform.workspace
  }
}

# Private Subnet AZ-a
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "${var.region}a"

  tags = {
    Name        = "${var.project}-${terraform.workspace}-priv-a"
    Environment = terraform.workspace
  }
}

# Private Subnet AZ-b
resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.12.0/24"
  availability_zone = "${var.region}b"

  tags = {
    Name        = "${var.project}-${terraform.workspace}-priv-b"
    Environment = terraform.workspace
  }
}

# Elastic IP para NAT Gateway A
resource "aws_eip" "nat_a" {
  domain = "vpc"

  tags = {
    Name        = "${var.project}-${terraform.workspace}-eip-a"
    Environment = terraform.workspace
  }
}

# Elastic IP para NAT Gateway B
resource "aws_eip" "nat_b" {
  domain = "vpc"

  tags = {
    Name        = "${var.project}-${terraform.workspace}-eip-b"
    Environment = terraform.workspace
  }
}

# NAT Gateway A
resource "aws_nat_gateway" "nat_a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id     = aws_subnet.public_a.id

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name        = "${var.project}-${terraform.workspace}-nat-a"
    Environment = terraform.workspace
  }
}

# NAT Gateway B
resource "aws_nat_gateway" "nat_b" {
  allocation_id = aws_eip.nat_b.id
  subnet_id     = aws_subnet.public_b.id

  depends_on = [aws_internet_gateway.main]

  tags = {
    Name        = "${var.project}-${terraform.workspace}-nat-b"
    Environment = terraform.workspace
  }
}

# Route Table publica
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.project}-${terraform.workspace}-rt-public"
    Environment = terraform.workspace
  }
}

# Route Table privada AZ-a
resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_a.id
  }

  tags = {
    Name        = "${var.project}-${terraform.workspace}-rt-priv-a"
    Environment = terraform.workspace
  }
}

# Route Table privada AZ-b
resource "aws_route_table" "private_b" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_b.id
  }

  tags = {
    Name        = "${var.project}-${terraform.workspace}-rt-priv-b"
    Environment = terraform.workspace
  }
}

# Asociaciones de Route Tables
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_a.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_b.id
}
