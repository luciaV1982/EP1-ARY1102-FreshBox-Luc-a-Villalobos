# =====================================================
# FreshBox SpA - Application Load Balancer
# =====================================================

# Target Group
resource "aws_lb_target_group" "freshbox" {
  name     = "FreshBox-TG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.freshbox.id

  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }

  tags = {
    Name = "FreshBox-TG"
  }
}


# Application Load Balancer
resource "aws_lb" "freshbox" {
  name               = "FreshBox-ALB"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.alb.id]

  subnets = [
    aws_subnet.public_1a.id,
    aws_subnet.public_1b.id
  ]

  tags = {
    Name = "FreshBox-ALB"
  }
}

# Listener HTTP
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.freshbox.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.freshbox.arn
  }
}