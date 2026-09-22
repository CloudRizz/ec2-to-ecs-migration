# Execution role ARN used by Fargate to pull images and send logs.
output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution role"
  value       = aws_iam_role.ecs_task_execution.arn
}

# Task role ARN used by the application running inside the container.
output "ecs_task_role_arn" {
  description = "ARN of the ECS application task role"
  value       = aws_iam_role.ecs_task.arn
}

# Exposes the VPC Flow Logs role ARN to the networking module.
output "vpc_flow_logs_role_arn" {
  description = "ARN of the IAM role used by VPC Flow Logs"
  value       = aws_iam_role.vpc_flow_logs.arn
}