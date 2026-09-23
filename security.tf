# =====================================================
# FreshBox SpA - Security Groups
# Flujo: Internet -> ALB -> APP -> DATA
# =====================================================

# SG DEL ALB
resource "aws_security_group" "alb" {
  name        = "FreshBox-SG-ALB"
  description = "Acceso HTTP y HTTPS desde Internet"
  vpc_id      = aws_vpc.freshbox.id

  ingress {
    description = "HTTP desde Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS desde Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "FreshBox-SG-ALB"
  }
}

# SG DE LAS EC2 APP
resource "aws_security_group" "app" {
  name        = "FreshBox-SG-APP"
  description = "Acceso desde ALB hacia contenedores FreshBox"
  vpc_id      = aws_vpc.freshbox.id

  ingress {
    description     = "Frontend desde ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "Microservicios desde ALB"
    from_port       = 3001
    to_port         = 3004
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "FreshBox-SG-APP"
  }
}

# SG DE MYSQL
resource "aws_security_group" "data" {
  name        = "FreshBox-SG-DATA"
  description = "MySQL accesible solamente desde capa APP"
  vpc_id      = aws_vpc.freshbox.id

  ingress {
    description     = "MySQL desde APP"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  ingress {
    description = "MySQL replicacion entre servidores DATA"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "FreshBox-SG-DATA"
  }
}