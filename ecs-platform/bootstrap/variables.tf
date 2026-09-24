# Defines the AWS region used for bootstrap resources
variable "aws_region" {
  description = "AWS region used to deploy the boostrap infrastructure"
  type        = string
  default     = "eu-west-2"
}

# Defines the project name used for resource naming and tagging
variable "project_name" {
  description = "Project name used to identify bootstrap resources"
  type        = string
  default     = "ec2-to-ecs-migration"
}
