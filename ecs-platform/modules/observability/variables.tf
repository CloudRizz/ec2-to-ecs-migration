# Prefix used to consistently name CloudWatch monitoring resources.
variable "name_prefix" {
  description = "Prefix used for observability resource names"
  type        = string
}

# ECS cluster name used as a CloudWatch metric dimension.
variable "ecs_cluster_name" {
  description = "Name of the ECS cluster to monitor"
  type        = string
}

# ECS service name used as a CloudWatch metric dimension.
variable "ecs_service_name" {
  description = "Name of the ECS service to monitor"
  type        = string
}

# ALB ARN suffix used by CloudWatch ApplicationELB metrics.
variable "alb_arn_suffix" {
  description = "ARN suffix of the Application Load Balancer"
  type        = string
}

# Target group ARN suffix used by CloudWatch ApplicationELB metrics.
variable "target_group_arn_suffix" {
  description = "ARN suffix of the ALB target group"
  type        = string
}

# Common tags applied to observability resources.
variable "tags" {
  description = "Tags applied to observability resources"
  type        = map(string)
  default     = {}
}
