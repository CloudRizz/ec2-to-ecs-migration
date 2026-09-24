# The name of the ECR repository used to store application container images.
variable "repository_name" {
  description = "name of the Amazon ECR repository"
  type        = string
}

# Immutable tags prevent an existing image tag from being overwritten. 
variable "image_tag_mutability" {
  description = "whether image tags can be overwritten"
  type        = string
  default     = "IMMUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be either MUTABLE or IMMUTABLE"
  }
}

# Enable ECR Image scanning when an image is pushed to help identify vulnerabilities in app images. 
variable "scan_on_push" {
  description = "whether ECR should scan container images pushed"
  type        = bool
  default     = true
}

# Lifecycle policy - delete older images 
variable "max_image_count" {
  type    = number
  default = 20

  validation {
    condition     = var.max_image_count > 0
    error_message = "max_image_count must be greater than zero"
  }
}

# Additional resource tags
variable "tags" {
  description = "Tags to apply to ECR resources"
  type        = map(string)
  default     = {}
}

