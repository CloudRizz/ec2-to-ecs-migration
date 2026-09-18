# =============================================================================
# Production Environment - EC2 to ECS Migration
# =============================================================================
# Builds the production ECS Fargate platform using reusable Terraform modules.
#
# Architecture:
# Internet -> ALB -> ECS Fargate -> Flask API
#
# - ALB deployed in public subnets
# - ECS tasks isolated in private subnets across multiple AZs
# - ECR stores immutable application images
# - IAM provides least-privilege access
# - CloudWatch provides logging, metrics, and alarms
# - Auto Scaling manages ECS task capacity
# - Existing EC2 deployment remains available during the controlled cutover
# =============================================================================

# Multi-AZ VPC with public subnets for the ALB and private subnets for ECS.
module "networking" {
  source = "../../modules/networking"

  # Shared naming convention used throughout the platform.
  name_prefix = local.name_prefix

  # Network configuration is defined at the environment level and passed
  # into the reusable networking module.
  vpc_cidr        = var.vpc_cidr
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  # Apply the same project/environment tags consistently to all resources.
  tags = local.common_tags
}

# Creates the private ECR repository for immutable application imageges
module "ecr" {
  source = "../../modules/ecr"

  # shared naming convention
  repository_name = "${local.name_prefix}-app"

  # Pass common env tags into the reusable module
  tags = local.common_tags
}

# Provides the public entry point and forwards traffic to private ECS tasks.
module "alb" {
  source = "../../modules/alb"

  name_prefix       = local.name_prefix
  vpc_id            = module.networking.vpc_id
  public_subnet_ids = module.networking.public_subnet_ids

  tags = local.common_tags
}

# Provides separate least-privilege roles for Fargate and the application.
module "iam" {
  source = "../../modules/iam"

  name_prefix = local.name_prefix
  tags        = local.common_tags
}

# Runs the containerised Flask API on Fargate behind the public ALB.
module "ecs" {
  source = "../../modules/ecs"

  name_prefix           = local.name_prefix
  aws_region            = var.aws_region
  vpc_id                = module.networking.vpc_id
  private_subnet_ids    = module.networking.private_subnet_ids
  alb_security_group_id = module.alb.security_group_id
  target_group_arn      = module.alb.target_group_arn

  container_image    = "${module.ecr.repository_url}:${var.image_tag}"
  execution_role_arn = module.iam.ecs_task_execution_role_arn
  task_role_arn      = module.iam.ecs_task_role_arn

  # Ensures the ALB listener exists before ECS registers the service.
  depends_on = [module.alb]

  tags = local.common_tags

}

