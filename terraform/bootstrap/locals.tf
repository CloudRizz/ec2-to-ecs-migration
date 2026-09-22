# Builds a globally unique name for the terraform state bucket
locals {
  state_bucket_name = "${var.project_name}-tfstate-${random_id.state_bucket_suffix.hex}"
}