# ALB Security group - allow incoming traffic
resource "aws_security_group" "alb" {
  # checkov:skip=CKV_AWS_260:Public HTTP ingress is required for the current portfolio deployment; HTTPS with ACM is documented as a production improvement.
  name        = "${var.name_prefix}-alb-sg"
  description = "SG for the public application load balancer"
  vpc_id      = var.vpc_id

  ingress {
    description = "Allow HTTP traffic from the internet"
    from_port   = var.listener_port
    to_port     = var.listener_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allows the ALB to send application traffic only to targets on the configured app port.
  egress {
    description = "Allow outbound traffic to application targets"
    from_port   = var.target_port
    to_port     = var.target_port
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-alb-sg"
    }
  )
}

# ALB
resource "aws_lb" "this" {
  # checkov:skip=CKV_AWS_150:Deletion protection is disabled so the short-lived environment can be destroyed cleanly.
  # checkov:skip=CKV_AWS_91:ALB access logging is deferred for this short-lived portfolio environment; VPC Flow Logs, ECS logs and CloudWatch metrics provide the current observability layer.
  # checkov:skip=CKV2_AWS_28:AWS WAF is deferred for this short-lived portfolio environment and would be added for a production internet-facing workload.
  # checkov:skip=CKV2_AWS_20:HTTP-to-HTTPS redirection is deferred until ACM and a production DNS name are introduced.
  name               = "${var.name_prefix}-alb"
  internal           = false # make the ALB public/internet facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet_ids

  # Drops malformed HTTP headers before requests are forwarded to the application.
  drop_invalid_header_fields = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-alb"
    }
  )
}

# ALB Target Group
resource "aws_lb_target_group" "app" {
  # checkov:skip=CKV_AWS_378:ALB-to-Fargate traffic remains HTTP inside the VPC; end-to-end TLS is deferred as a production hardening improvement.
  name        = "${var.name_prefix}-tg"
  port        = var.target_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  # Use the application's existing health endpoint to determine whether a task
  # is healthy and should receive traffic from the ALB.
  health_check {
    enabled             = true
    path                = var.health_check_path
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-tg"
    }
  )
}

# ALB - HTTP Listener - forwards traffic to application target group
resource "aws_lb_listener" "http" {
  # checkov:skip=CKV_AWS_2:HTTP is intentionally used for the current portfolio deployment; HTTPS with ACM is a documented production improvement.
  # checkov:skip=CKV_AWS_103:TLS policy is not applicable to the current HTTP listener and would be enforced when HTTPS is introduced.
  load_balancer_arn = aws_lb.this.arn
  port              = var.listener_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }

  tags = var.tags
}
