# Configures the AWS provider for the bootstrap infrastructure
provider "aws" {
  region = var.aws_region

  # Applies consistent ownership tags to supported bootstrap resources
  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "Terraform"
      Layer     = "Bootstrap"
    }
  }
}
