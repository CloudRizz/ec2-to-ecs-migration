# Generates a persistent random suffix to make the globally scoped s3 bucket name unique
resource "random_id" "state_bucket_suffix" {
  byte_length = 4
}

# creates the persistent S3 bucket used to store production terraform state
resource "aws_s3_bucket" "terraform_state" {
  # checkov:skip=CKV_AWS_18:S3 access logging is deferred for this short-lived bootstrap environment; state access is limited to the deployment role and protected by bucket access controls.
  # checkov:skip=CKV_AWS_145:AWS-managed S3 encryption is sufficient for this portfolio environment; a customer-managed KMS key is deferred.
  # checkov:skip=CKV2_AWS_62:S3 event notifications are not required for Terraform state operation and are deferred as a production enhancement.
  # checkov:skip=CKV_AWS_144:Cross-region replication is deferred for this portfolio environment; versioning provides the current state recovery mechanism.
  bucket = local.state_bucket_name
}

# Enabnles versioning so previous terrafrom state versions can be recovered
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encryptes Terraform state at rest using a3 server side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Blocks all forms of public access to the terraform state bucket
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Publishes the generated state bucket name so deployment workflows can discover the backend automatically.
resource "aws_ssm_parameter" "state_bucket_name" {
  # checkov:skip=CKV_AWS_337:The parameter contains only the Terraform state bucket name; AWS-managed encryption is sufficient and a customer-managed KMS key is not required.
  name        = "/${var.project_name}/bootstrap/state-bucket"
  description = "Terraform remote-state bucket used by the production deployment pipeline"
  type        = "SecureString" # Encrypts the backend discovery parameter at rest in Parameter Store.
  value       = aws_s3_bucket.terraform_state.bucket

  tags = {
    Name    = "${var.project_name}-state-bucket"
    Purpose = "Terraform backend discovery"
  }
}

# Removes old Terraform state versions after a recovery window to control long-term storage growth.
resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "expire-old-state-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
    # Cleans up incomplete multipart uploads that never successfully finish.
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Creates the persistent ECR repository required before application deployments can push images.
module "ecr" {
  source = "../modules/ecr"

  # Uses the same repository name previously owned by the production environment.
  repository_name = "${var.project_name}-prod-app"

  # Identifies the repository as a persistent deployment prerequisite.
  tags = {
    Project     = var.project_name
    Environment = "prod"
    ManagedBy   = "Terraform"
    Purpose     = "Application image repository"
  }
}

