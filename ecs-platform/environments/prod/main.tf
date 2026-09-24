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

  # Supplies the Flow Logs publishing role managed by the IAM module.
  vpc_flow_logs_role_arn = module.iam.vpc_flow_logs_role_arn

  # Apply the same project/environment tags consistently to all resources.
  tags = local.common_tags
}

# Provides the public entry point and forwards traffic to private ECS tasks.
module "alb" {
  source = "../../modules/alb"

  name_prefix       = local.name_prefix
  vpc_id            = module.networking.vpc_id
  public_subnet_ids = module.networking.public_subnet_ids
  # Restricts ALB egress to the application targets inside the VPC.
  vpc_cidr = module.networking.vpc_cidr

  tags = local.common_tags
}

# =============================================================================
# Route53 DNS Cutover
# =============================================================================

# Discovers the existing public hosted zone for the migration domain.
data "aws_route53_zone" "primary" {
  name         = "twrz.co.uk"
  private_zone = false
}

# Routes the migration hostname directly to the ECS Application Load Balancer.
resource "aws_route53_record" "migration" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = "migration.twrz.co.uk"
  type    = "A"

  alias {
    name                   = module.alb.alb_dns_name
    zone_id                = module.alb.alb_zone_id
    evaluate_target_health = true
  }
}

# Provides separate least-privilege roles for Fargate and the application.
module "iam" {
  source = "../../modules/iam"

  name_prefix = local.name_prefix
  tags        = local.common_tags
}

# Persistent bootstrap-owned ECR repository.
data "aws_ecr_repository" "app" {
  name = "${var.project_name}-${var.environment}-app"
}

# Used only when image_tag is not explicitly supplied.
data "aws_ecr_image" "latest" {
  repository_name = data.aws_ecr_repository.app.name
  most_recent     = true
}

locals {
  container_image = var.image_tag != null ? (
    "${data.aws_ecr_repository.app.repository_url}:${var.image_tag}"
    ) : (
    "${data.aws_ecr_repository.app.repository_url}@${data.aws_ecr_image.latest.image_digest}"
  )
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

  # Deploys the immutable image from the persistent bootstrap-owned ECR repository.
  container_image    = local.container_image
  execution_role_arn = module.iam.ecs_task_execution_role_arn
  task_role_arn      = module.iam.ecs_task_role_arn

  # Ensures the ALB listener exists before ECS registers the service.
  depends_on = [module.alb]

  tags = local.common_tags

}

# Creates CloudWatch monitoring for the ECS service and application load balancer.
module "observability" {
  source = "../../modules/observability"

  name_prefix             = local.name_prefix
  ecs_cluster_name        = module.ecs.cluster_name
  ecs_service_name        = module.ecs.service_name
  alb_arn_suffix          = module.alb.alb_arn_suffix
  target_group_arn_suffix = module.alb.target_group_arn_suffix

  tags = local.common_tags
}

