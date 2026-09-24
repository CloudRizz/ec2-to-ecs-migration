# Prefix used to create consistent ECS resource names.
variable "name_prefix" {
  description = "Prefix used for ECS resource names"
  type        = string
}

# VPC where the ECS service and security group will be deployed.
variable "vpc_id" {
  description = "ID of the VPC used by the ECS service"
  type        = string
}

# Private subnets used to run the Fargate tasks.
variable "private_subnet_ids" {
  description = "Private subnet IDs used by the ECS service"
  type        = list(string)
}

# ALB security group allowed to send traffic to the Fargate tasks.
variable "alb_security_group_id" {
  description = "Security group ID of the application load balancer"
  type        = string
}

# ALB target group where the ECS service registers its tasks.
variable "target_group_arn" {
  description = "ARN of the ALB target group"
  type        = string
}

# ECR image URI used by the ECS task definition.
variable "container_image" {
  description = "Container image URI used by the ECS task"
  type        = string
}

# IAM execution role used by Fargate to pull images and publish logs.
variable "execution_role_arn" {
  description = "ARN of the ECS task execution role"
  type        = string
}

# IAM task role assumed by the application container.
variable "task_role_arn" {
  description = "ARN of the ECS application task role"
  type        = string
}

# Port exposed by the Flask application container.
variable "container_port" {
  description = "Port exposed by the application container"
  type        = number
  default     = 5000
}

# CPU units allocated to each Fargate task.
variable "task_cpu" {
  description = "CPU units allocated to the Fargate task"
  type        = number
  default     = 256
}

# Memory allocated to each Fargate task in MiB.
variable "task_memory" {
  description = "Memory allocated to the Fargate task in MiB"
  type        = number
  default     = 512
}

# Number of application tasks maintained by the ECS service.
variable "desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
  default     = 1
}

# AWS Region used by the container logging configuration.
variable "aws_region" {
  description = "AWS Region used by ECS and CloudWatch Logs"
  type        = string
}

# Common tags applied across ECS resources.
variable "tags" {
  description = "Common tags applied to ECS resources"
  type        = map(string)
  default     = {}
}

# Minimum number of Fargate tasks maintained by Service Auto Scaling.
variable "min_capacity" {
  description = "Minimum number of ECS tasks"
  type        = number
  default     = 1
}

# Maximum number of Fargate tasks allowed by Service Auto Scaling.
variable "max_capacity" {
  description = "Maximum number of ECS tasks"
  type        = number
  default     = 2
}

# Average CPU utilisation that ECS Service Auto Scaling will target.
variable "cpu_target_value" {
  description = "Target average CPU utilisation percentage"
  type        = number
  default     = 60
}