# =====================================================
# FreshBox SpA - Red
# VPC Multi-AZ con 6 subredes
# =====================================================

# VPC
resource "aws_vpc" "freshbox" {
  cidr_block           = "10.0.0.0/22"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "FreshBox-VPC"
  }
}

# =====================================================
# SUBREDES PUBLICAS - ALB / NAT
# =====================================================

resource "aws_subnet" "public_1a" {
  vpc_id                  = aws_vpc.freshbox.id
  cidr_block              = "10.0.0.0/26"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "FreshBox-PUBLIC-1A"
  }
}

resource "aws_subnet" "public_1b" {
  vpc_id                  = aws_vpc.freshbox.id
  cidr_block              = "10.0.0.64/26"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "FreshBox-PUBLIC-1B"
  }
}

# =====================================================
# SUBREDES PRIVADAS APP - EC2 + Docker
# =====================================================

resource "aws_subnet" "app_1a" {
  vpc_id            = aws_vpc.freshbox.id
  cidr_block        = "10.0.1.0/26"
  availability_zone = "us-east-1a"

  tags = {
    Name = "FreshBox-APP-1A"
  }
}

resource "aws_subnet" "app_1b" {
  vpc_id            = aws_vpc.freshbox.id
  cidr_block        = "10.0.1.64/26"
  availability_zone = "us-east-1b"

  tags = {
    Name = "FreshBox-APP-1B"
  }
}

# =====================================================
# SUBREDES PRIVADAS DATA - MySQL
# =====================================================

resource "aws_subnet" "data_1a" {
  vpc_id            = aws_vpc.freshbox.id
  cidr_block        = "10.0.2.0/26"
  availability_zone = "us-east-1a"

  tags = {
    Name = "FreshBox-DATA-1A"
  }
}

resource "aws_subnet" "data_1b" {
  vpc_id            = aws_vpc.freshbox.id
  cidr_block        = "10.0.2.64/26"
  availability_zone = "us-east-1b"

  tags = {
    Name = "FreshBox-DATA-1B"
  }
}

# =====================================================
# INTERNET GATEWAY
# =====================================================

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.freshbox.id

  tags = {
    Name = "FreshBox-IGW"
  }
}

# =====================================================
# NAT GATEWAY - PUBLIC-1A
# =====================================================

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "FreshBox-NAT-EIP"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public_1a.id

  depends_on = [aws_internet_gateway.igw]

  tags = {
    Name = "FreshBox-NAT-GW"
  }
}

# =====================================================
# TABLA DE RUTAS PUBLICA
# =====================================================

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.freshbox.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "FreshBox-RT-PUBLIC"
  }
}

resource "aws_route_table_association" "public_1a" {
  subnet_id      = aws_subnet.public_1a.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_1b" {
  subnet_id      = aws_subnet.public_1b.id
  route_table_id = aws_route_table.public.id
}

# =====================================================
# TABLA DE RUTAS PRIVADA
# =====================================================

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.freshbox.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "FreshBox-RT-PRIVATE"
  }
}

resource "aws_route_table_association" "app_1a" {
  subnet_id      = aws_subnet.app_1a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "app_1b" {
  subnet_id      = aws_subnet.app_1b.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "data_1a" {
  subnet_id      = aws_subnet.data_1a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "data_1b" {
  subnet_id      = aws_subnet.data_1b.id
  route_table_id = aws_route_table.private.id
}