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
  description = "Deployment Environment"
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
  description = "additional tages to merge with the default project tags"
  type        = map(string)
  default     = {}
}

# Immutable ECR image tag deployed to the ECS service.
variable "image_tag" {
  description = "Immutable ECR image tag deployed to ECS"
  type        = string
}

