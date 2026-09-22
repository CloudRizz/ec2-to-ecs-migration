# =============================================================================
# GitHub Actions Deployment Policies
# =============================================================================
# Splits deployment permissions across multiple managed policies to stay within
# AWS IAM managed-policy size limits while preserving least-privilege access.
# =============================================================================


# =============================================================================
# Terraform State and Backend Discovery
# =============================================================================

# Builds the permissions required to access the production Terraform backend.
data "aws_iam_policy_document" "github_actions_state" {

  # Allows Terraform to inspect the remote-state bucket.
  statement {
    sid    = "TerraformStateBucket"
    effect = "Allow"

    actions = [
      "s3:GetBucketVersioning",
      "s3:ListBucket"
    ]

    resources = [
      aws_s3_bucket.terraform_state.arn
    ]
  }

  # Allows Terraform to read and update only the production state and lock objects.
  statement {
    sid    = "TerraformStateObjects"
    effect = "Allow"

    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:PutObject"
    ]

    resources = [
      "${aws_s3_bucket.terraform_state.arn}/prod/terraform.tfstate",
      "${aws_s3_bucket.terraform_state.arn}/prod/terraform.tfstate.tflock"
    ]
  }

  # Allows GitHub Actions to discover the remote-state bucket through Parameter Store.
  statement {
    sid    = "TerraformBackendDiscovery"
    effect = "Allow"

    actions = [
      "ssm:GetParameter"
    ]

    resources = [
      "arn:aws:ssm:${var.aws_region}:*:parameter/${var.project_name}/bootstrap/state-bucket"
    ]
  }
}


# =============================================================================
# Networking and Application Load Balancer
# =============================================================================

# Builds the permissions required to provision the production network and ALB.
data "aws_iam_policy_document" "github_actions_networking" {
  # checkov:skip=CKV_AWS_356:EC2 provisioning spans multiple dynamically-created VPC resources and several operations require wildcard resource scope.
  # checkov:skip=CKV_AWS_111:Terraform requires EC2 write access across dynamically-created VPC resources; access remains constrained by the GitHub OIDC deployment role.

  # Allows Terraform to create, inspect, modify and destroy the VPC networking used by ECS.
  statement {
    sid    = "TerraformNetworking"
    effect = "Allow"

    actions = [
      "ec2:AllocateAddress",
      "ec2:AssociateRouteTable",
      "ec2:AttachInternetGateway",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CreateFlowLogs",
      "ec2:CreateInternetGateway",
      "ec2:CreateNatGateway",
      "ec2:CreateRoute",
      "ec2:CreateRouteTable",
      "ec2:CreateSecurityGroup",
      "ec2:CreateSubnet",
      "ec2:CreateTags",
      "ec2:CreateVpc",
      "ec2:DeleteFlowLogs",
      "ec2:DeleteInternetGateway",
      "ec2:DeleteNatGateway",
      "ec2:DeleteRoute",
      "ec2:DeleteRouteTable",
      "ec2:DeleteSecurityGroup",
      "ec2:DeleteSubnet",
      "ec2:DeleteTags",
      "ec2:DeleteVpc",
      "ec2:DescribeAddresses",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeFlowLogs",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeNatGateways",
      "ec2:DescribeNetworkAcls",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeRouteTables",
      "ec2:DescribeSecurityGroupRules",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcAttribute",
      "ec2:DescribeVpcs",
      "ec2:DetachInternetGateway",
      "ec2:DisassociateRouteTable",
      "ec2:ModifySubnetAttribute",
      "ec2:ModifyVpcAttribute",
      "ec2:ReleaseAddress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress"
    ]

    resources = ["*"]
  }

  # Allows Terraform to inspect ALB resources because these describe APIs are account-scoped.
  statement {
    sid    = "DescribeELBResources"
    effect = "Allow"

    actions = [
      "elasticloadbalancing:DescribeListenerAttributes",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeTags",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetGroups"
    ]

    resources = ["*"]
  }

  # Allows Terraform to manage only this project's ALB resources.
  statement {
    sid    = "TerraformELBResources"
    effect = "Allow"

    actions = [
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:RemoveTags"
    ]

    resources = [
      "arn:aws:elasticloadbalancing:${var.aws_region}:*:loadbalancer/app/${var.project_name}-prod-alb/*",
      "arn:aws:elasticloadbalancing:${var.aws_region}:*:listener/app/${var.project_name}-prod-alb/*/*",
      "arn:aws:elasticloadbalancing:${var.aws_region}:*:targetgroup/${var.project_name}-prod-tg/*"
    ]
  }
}


# =============================================================================
# ECS, ECR, Auto Scaling and Observability
# =============================================================================

# Builds the application-platform permissions used by the deployment pipeline.
data "aws_iam_policy_document" "github_actions_platform" {
  # checkov:skip=CKV_AWS_356:Remaining wildcard resources are limited to AWS APIs that do not support practical resource-level scoping; all resource-capable platform actions are scoped to project resources.

  # Allows Terraform to inspect only this project's ECS cluster.
  statement {
    sid    = "DescribeECSCluster"
    effect = "Allow"

    actions = [
      "ecs:DescribeClusters"
    ]

    resources = [
      "arn:aws:ecs:${var.aws_region}:*:cluster/${var.project_name}-prod-cluster"
    ]
  }

  # Allows Terraform to inspect task definitions because this API does not support resource-level scoping.
  statement {
    sid    = "DescribeECSTaskDefinition"
    effect = "Allow"

    actions = [
      "ecs:DescribeTaskDefinition"
    ]

    resources = ["*"]
  }

  # Allows Terraform to list ECS resources that require account-level scope.
  statement {
    sid    = "ListECSResources"
    effect = "Allow"

    actions = [
      "ecs:ListServices",
      "ecs:ListTaskDefinitions"
    ]

    resources = ["*"]
  }

  # Allows Terraform to manage only this project's ECS cluster and service.
  statement {
    sid    = "TerraformECSService"
    effect = "Allow"

    actions = [
      "ecs:CreateCluster",
      "ecs:CreateService",
      "ecs:DeleteCluster",
      "ecs:DeleteService",
      "ecs:DescribeServices",
      "ecs:ListTagsForResource",
      "ecs:TagResource",
      "ecs:UntagResource",
      "ecs:UpdateService"
    ]

    resources = [
      "arn:aws:ecs:${var.aws_region}:*:cluster/${var.project_name}-prod-cluster",
      "arn:aws:ecs:${var.aws_region}:*:service/${var.project_name}-prod-cluster/${var.project_name}-prod-service"
    ]
  }

  # Allows Terraform to register and manage only this project's task-definition family.
  statement {
    sid    = "TerraformECSTaskDefinitions"
    effect = "Allow"

    actions = [
      "ecs:DeregisterTaskDefinition",
      "ecs:RegisterTaskDefinition",
      "ecs:TagResource",
      "ecs:UntagResource"
    ]

    resources = [
      "arn:aws:ecs:${var.aws_region}:*:task-definition/${var.project_name}-prod:*"
    ]
  }

  # Allows Docker to request the temporary ECR authentication token.
  statement {
    sid    = "ECRAuthentication"
    effect = "Allow"

    actions = [
      "ecr:GetAuthorizationToken"
    ]

    resources = ["*"]
  }

  # Allows the workflow to discover only the bootstrap-owned project repository.
  statement {
    sid    = "ECRRepositoryDiscovery"
    effect = "Allow"

    actions = [
      "ecr:DescribeRepositories"
    ]

    resources = [
      "arn:aws:ecr:${var.aws_region}:*:repository/${var.project_name}-prod-app"
    ]
  }

  # Allows GitHub Actions to push images only to this project's ECR repository.
  statement {
    sid    = "ECRImagePush"
    effect = "Allow"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]

    resources = [
      "arn:aws:ecr:${var.aws_region}:*:repository/${var.project_name}-prod-app"
    ]
  }

  # Allows Terraform to inspect ECS Application Auto Scaling configuration.
  statement {
    sid    = "DescribeAutoScaling"
    effect = "Allow"

    actions = [
      "application-autoscaling:DescribeScalableTargets",
      "application-autoscaling:DescribeScalingPolicies"
    ]

    resources = ["*"]
  }

  # Allows Terraform to manage only ECS desired-count scaling targets.
  statement {
    sid    = "TerraformAutoScaling"
    effect = "Allow"

    actions = [
      "application-autoscaling:DeleteScalingPolicy",
      "application-autoscaling:DeregisterScalableTarget",
      "application-autoscaling:PutScalingPolicy",
      "application-autoscaling:RegisterScalableTarget",
      "application-autoscaling:TagResource",
      "application-autoscaling:UntagResource"
    ]

    resources = [
      "arn:aws:application-autoscaling:${var.aws_region}:*:scalable-target/*"
    ]

    # Restricts scaling changes to the ECS service namespace.
    condition {
      test     = "StringEquals"
      variable = "application-autoscaling:service-namespace"

      values = [
        "ecs"
      ]
    }

    # Restricts scaling changes to ECS service desired-count targets.
    condition {
      test     = "StringEquals"
      variable = "application-autoscaling:scalable-dimension"

      values = [
        "ecs:service:DesiredCount"
      ]
    }
  }

  # Allows Terraform to manage only this project's CloudWatch log groups.
  statement {
    sid    = "TerraformLogGroups"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:ListTagsForResource",
      "logs:PutRetentionPolicy",
      "logs:TagResource",
      "logs:UntagResource"
    ]

    resources = [
      "arn:aws:logs:${var.aws_region}:*:log-group:/ecs/${var.project_name}-prod*",
      "arn:aws:logs:${var.aws_region}:*:log-group:/aws/vpc/${var.project_name}-prod-flow-logs*"
    ]
  }

  # Allows Terraform to discover CloudWatch log groups.
  statement {
    sid    = "DescribeLogGroups"
    effect = "Allow"

    actions = [
      "logs:DescribeLogGroups"
    ]

    resources = ["*"]
  }

  # Allows Terraform to manage only this project's CloudWatch alarms.
  statement {
    sid    = "TerraformCloudWatchAlarms"
    effect = "Allow"

    actions = [
      "cloudwatch:DeleteAlarms",
      "cloudwatch:ListTagsForResource",
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:TagResource",
      "cloudwatch:UntagResource"
    ]

    resources = [
      "arn:aws:cloudwatch:${var.aws_region}:*:alarm:${var.project_name}-prod-*"
    ]
  }

  # Allows Terraform to inspect alarm state during refresh and planning.
  statement {
    sid    = "DescribeCloudWatchAlarms"
    effect = "Allow"

    actions = [
      "cloudwatch:DescribeAlarms"
    ]

    resources = ["*"]
  }
}


# =============================================================================
# IAM and PassRole
# =============================================================================

# Builds the IAM permissions required for ECS and VPC Flow Logs roles.
data "aws_iam_policy_document" "github_actions_iam" {

  # Allows Terraform to manage only the ECS roles used by this project.
  statement {
    sid    = "TerraformECSIAMRoles"
    effect = "Allow"

    actions = [
      "iam:AttachRolePolicy",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:DetachRolePolicy",
      "iam:GetRole",
      "iam:ListAttachedRolePolicies",
      "iam:ListRolePolicies",
      "iam:TagRole",
      "iam:UntagRole"
    ]

    resources = [
      "arn:aws:iam::*:role/${var.project_name}-prod-ecs-execution-role",
      "arn:aws:iam::*:role/${var.project_name}-prod-ecs-task-role"
    ]
  }

  # Allows Terraform to manage only the dedicated VPC Flow Logs role.
  statement {
    sid    = "TerraformVPCFlowLogsIAMRole"
    effect = "Allow"

    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListRolePolicies",
      "iam:PutRolePolicy",
      "iam:TagRole",
      "iam:UntagRole"
    ]

    resources = [
      "arn:aws:iam::*:role/${var.project_name}-prod-vpc-flow-logs-role"
    ]
  }

  # Allows Terraform to inspect the AWS-managed ECS task execution policy.
  statement {
    sid    = "ReadECSManagedPolicy"
    effect = "Allow"

    actions = [
      "iam:GetPolicy",
      "iam:GetPolicyVersion"
    ]

    resources = [
      "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
    ]
  }

  # Allows only project ECS roles to be passed to the ECS tasks service.
  statement {
    sid    = "PassECSRoles"
    effect = "Allow"

    actions = [
      "iam:PassRole"
    ]

    resources = [
      "arn:aws:iam::*:role/${var.project_name}-prod-ecs-execution-role",
      "arn:aws:iam::*:role/${var.project_name}-prod-ecs-task-role"
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"

      values = [
        "ecs-tasks.amazonaws.com"
      ]
    }
  }

  # Allows only the dedicated Flow Logs role to be passed to the Flow Logs service.
  statement {
    sid    = "PassVPCFlowLogsRole"
    effect = "Allow"

    actions = [
      "iam:PassRole"
    ]

    resources = [
      "arn:aws:iam::*:role/${var.project_name}-prod-vpc-flow-logs-role"
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"

      values = [
        "vpc-flow-logs.amazonaws.com"
      ]
    }
  }
}


# =============================================================================
# Managed Policies
# =============================================================================

# Creates the backend-access policy used by the GitHub deployment role.
resource "aws_iam_policy" "github_actions_state" {
  name        = "${var.project_name}-github-actions-state"
  description = "Terraform backend permissions for GitHub Actions"

  policy = data.aws_iam_policy_document.github_actions_state.json
}

# Creates the networking deployment policy used by the GitHub deployment role.
resource "aws_iam_policy" "github_actions_networking" {
  name        = "${var.project_name}-github-actions-networking"
  description = "Networking and ALB deployment permissions for GitHub Actions"

  policy = data.aws_iam_policy_document.github_actions_networking.json
}

# Creates the application-platform policy used by the GitHub deployment role.
resource "aws_iam_policy" "github_actions_platform" {
  name        = "${var.project_name}-github-actions-platform"
  description = "ECS, ECR, scaling and observability permissions for GitHub Actions"

  policy = data.aws_iam_policy_document.github_actions_platform.json
}

# Creates the IAM-management policy used by the GitHub deployment role.
resource "aws_iam_policy" "github_actions_iam" {
  name        = "${var.project_name}-github-actions-iam"
  description = "IAM and PassRole permissions for GitHub Actions"

  policy = data.aws_iam_policy_document.github_actions_iam.json
}


# =============================================================================
# Role Attachments
# =============================================================================

# Attaches Terraform backend permissions to the GitHub Actions OIDC role.
resource "aws_iam_role_policy_attachment" "github_actions_state" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_state.arn
}

# Attaches networking permissions to the GitHub Actions OIDC role.
resource "aws_iam_role_policy_attachment" "github_actions_networking" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_networking.arn
}

# Attaches platform permissions to the GitHub Actions OIDC role.
resource "aws_iam_role_policy_attachment" "github_actions_platform" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_platform.arn
}

# Attaches IAM management permissions to the GitHub Actions OIDC role.
resource "aws_iam_role_policy_attachment" "github_actions_iam" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_iam.arn
}
