# Generates a persistent random suffix to make the globally scoped s3 bucket name unique
resource "random_id" "state_bucket_suffix" {
  byte_length = 4
}

# creates the persistent S3 bucket used to store production terraform state
resource "aws_s3_bucket" "terraform_state" {
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
  name        = "/${var.project_name}/bootstrap/state-bucket"
  description = "Terraform remote-state bucket used by the production deployment pipeline"
  type        = "String"
  value       = aws_s3_bucket.terraform_state.bucket

  tags = {
    Name    = "${var.project_name}-state-bucket"
    Purpose = "Terraform backend discovery"
  }
}
