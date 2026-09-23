# =====================================================
# FreshBox SpA - Outputs
# =====================================================

output "alb_dns" {
  description = "DNS publico del Application Load Balancer"
  value       = aws_lb.freshbox.dns_name
}

output "mysql_private_ip" {
  description = "IP privada de la EC2 MySQL"
  value       = aws_instance.mysql.private_ip
}

output "autoscaling_group_name" {
  description = "Nombre del Auto Scaling Group de FreshBox"
  value       = aws_autoscaling_group.app.name
}

output "freshbox_url" {
  description = "URL publica de FreshBox"
  value       = "http://${aws_lb.freshbox.dns_name}"
}