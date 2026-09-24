# Output ECR repository by name
output "repository_name" {
  description = "Name of the amazon ECR repo"
  value       = aws_ecr_repository.this.name
}

# Repo URL - ECS will use as part of the full container image reference
output "repository_url" {
  description = "URL of the amazon ECR repository"
  value       = aws_ecr_repository.this.repository_url
}

# Repo ARN - ARN uniquely identifies the repo within aws 
output "repository_arn" {
  description = "ARN of the amazon ECR repository"
  value       = aws_ecr_repository.this.arn
}

