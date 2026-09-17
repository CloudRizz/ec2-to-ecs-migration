# ECS cluster name used by deployments and operational commands.
output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.this.name
}

# ECS service name used by deployments and operational commands.
output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.app.name
}

# ECS task definition ARN used to identify the deployed application revision.
output "task_definition_arn" {
  description = "ARN of the ECS task definition"
  value       = aws_ecs_task_definition.app.arn
}

# ECS security group ID used by the Fargate tasks.
output "security_group_id" {
  description = "Security group ID of the ECS Fargate tasks"
  value       = aws_security_group.ecs.id
}

# CloudWatch log group containing the application container logs.
output "log_group_name" {
  description = "Name of the ECS CloudWatch log group"
  value       = aws_cloudwatch_log_group.ecs.name
}