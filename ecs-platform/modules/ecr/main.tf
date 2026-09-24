# Respository to store docker images for the application. ECS faragte will later pull image from repo
resource "aws_ecr_repository" "this" {
  # checkov:skip=CKV_AWS_136:AWS-managed AES-256 encryption is sufficient for this short-lived environment; a customer-managed KMS key is deferred.
  name                 = var.repository_name
  image_tag_mutability = var.image_tag_mutability

  # Scan images that are pushed to help identify known vulnerabilities.
  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  # Encrypt container images at rest using AWS-managed AES-256 encryption
  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(
    var.tags,
    {
      Name = var.repository_name
    }
  )
}

# ECR Lifecycle policy - delete older than 20 images
resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only the most recent ${var.max_image_count} images"

        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.max_image_count
        }

        action = {
          type = "expire"
        }
      }
    ]
  })
}

