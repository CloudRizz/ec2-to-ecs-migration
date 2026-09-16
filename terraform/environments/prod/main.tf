# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------
# Calls the reusable networking module that creates the shared AWS network
# for the ECS Fargate platform.
#
# The module creates:
# - VPC
# - Internet Gateway
# - Public subnets across multiple Availability Zones
# - Private subnets across multiple Availability Zones
# - NAT Gateways
# - Public and private route tables
#
# The public subnets will host internet-facing infrastructure such as the ALB.
# ECS Fargate tasks will run in the private subnets without public IP addresses.

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