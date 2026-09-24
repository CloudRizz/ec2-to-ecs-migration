# Exposes the state bucket name for production backend configuration and CI/CD.
output "state_bucket_name" {
  description = "Name of the S3 bucket used to store Terraform remote state"
  value       = aws_s3_bucket.terraform_state.id
}

# Exposes the state bucket ARN for IAM policy configuration.
output "state_bucket_arn" {
  description = "ARN of the S3 bucket used to store Terraform remote state"
  value       = aws_s3_bucket.terraform_state.arn
}

# Exposes the persistent ECR repository name for deployment workflows.
output "ecr_repository_name" {
  description = "Name of the ECR repository used for application images"
  value       = module.ecr.repository_name
}

# Exposes the persistent ECR repository URL for image build and deployment workflows.
output "ecr_repository_url" {
  description = "URL of the ECR repository used for application images"
  value       = module.ecr.repository_url
}

# Exposes the persistent ECR repository ARN for IAM and deployment references.
output "ecr_repository_arn" {
  description = "ARN of the ECR repository used for application images"
  value       = module.ecr.repository_arn
}
