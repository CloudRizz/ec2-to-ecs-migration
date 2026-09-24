variable "aws_region" {
  description = "AWS region for the ECS platform"
  type        = string
  default     = "eu-west-2"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "ec2-to-ecs-migration"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "prod"
}
variable "vpc_cidr" {
  description = "CIDR Block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "public subnet definitions"
  type = map(object({
    cidr = string
    az   = string
  }))

  default = {
    a = {
      cidr = "10.0.1.0/24"
      az   = "eu-west-2a"
    }

    b = {
      cidr = "10.0.2.0/24"
      az   = "eu-west-2b"
    }
  }
}

variable "private_subnets" {
  description = "Private Subnet Definitions"
  type = map(object({
    cidr = string
    az   = string
  }))

  default = {
    a = {
      cidr = "10.0.11.0/24"
      az   = "eu-west-2a"
    }

    b = {
      cidr = "10.0.12.0/24"
      az   = "eu-west-2b"
    }
  }
}
variable "tags" {
  description = "additional tags to merge with the default project tags"
  type        = map(string)
  default     = {}
}

# Optional immutable image tag.
# CI/CD supplies the Git commit SHA. Local runs fall back to the latest ECR image.
variable "image_tag" {
  description = "Optional immutable ECR image tag deployed to ECS"
  type        = string
  default     = null
}

variable "dns_target" {
  description = "Controls whether migration.twrz.co.uk routes to ECS or the legacy EC2 deployment"
  type        = string
  default     = "ecs"

  validation {
    condition     = contains(["ecs", "legacy"], var.dns_target)
    error_message = "dns_target must be either ecs or legacy."
  }
}

variable "legacy_eip" {
  description = "Elastic IP of the legacy EC2 deployment used for rollback"
  type        = string
  default     = "18.130.52.92"
}
