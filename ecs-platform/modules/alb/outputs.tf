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

# Load balancer Route53 hosted zone ID
output "alb_zone_id" {
  description = "Route53 hosted zone ID of the Application Load Balancer"
  value       = aws_lb.this.zone_id
}

# Exposes the target group ARN used to register ECS Fargate tasks.
output "target_group_arn" {
  description = "ARN of the application target group"
  value       = aws_lb_target_group.app.arn
}

# ALB Security Group
output "security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

# Exposes the ALB identifier required by CloudWatch metric dimensions.
output "alb_arn_suffix" {
  description = "ARN suffix of the Application Load Balancer"
  value       = aws_lb.this.arn_suffix
}

# Exposes the target group identifier required by CloudWatch metric dimensions.
output "target_group_arn_suffix" {
  description = "ARN suffix of the ALB target group"
  value       = aws_lb_target_group.app.arn_suffix
}

