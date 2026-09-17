# Load balancer ARN
output "alb_arn" {
  description = "ARN of the application load balancer"
  value       = aws_lb.this.arn
}

# Load balancer DNS Name
output "alb_dns_name" {
  description = "DNS name of the application load balancer"
  value       = aws_lb.this.dns_name
}

# Target group ARN
output "target_group_arn" {
  description = "ARN of the application target group"
  value       = aws_lb.this.arn
}

# ALB Security Group
output "security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

