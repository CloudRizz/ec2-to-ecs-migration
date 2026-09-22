# Builds the permissions used by GitHub Actions to deploy the production infrastructure.
data "aws_iam_policy_document" "github_actions_permissions" {

  # Allows Terraform to inspect the remote-state bucket and locate the production state.
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

  # Allows Terraform to read and update only the production state object.
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

  # Allows Terraform to create, inspect, modify and destroy the VPC networking used by the ECS platform.
  statement {
    # checkov:skip=CKV_AWS_356:EC2 provisioning actions span multiple VPC resource types and several require wildcard resource scope before resources exist.
    # checkov:skip=CKV_AWS_111:Terraform requires EC2 write actions across VPC resources during create/update/destroy; scope is limited by the GitHub OIDC trust and project deployment role.
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

  # Allows Terraform to inspect ECS resources that require account-wide read access.
  statement {
    sid    = "DescribeECSResources"
    effect = "Allow"

    actions = [
      "ecs:DescribeClusters",
      "ecs:DescribeTaskDefinition",
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

  # Allows Terraform to create the project ECR repository.
  statement {
    sid    = "TerraformECRCreate"
    effect = "Allow"

    actions = [
      "ecr:CreateRepository"
    ]

    resources = [
      "arn:aws:ecr:${var.aws_region}:*:repository/${var.project_name}-prod-app"
    ]
  }

  # Allows Terraform to manage only the project ECR repository.
  statement {
    sid    = "TerraformECRRepository"
    effect = "Allow"

    actions = [
      "ecr:DeleteLifecyclePolicy",
      "ecr:DeleteRepository",
      "ecr:DescribeImages",
      "ecr:DescribeRepositories",
      "ecr:GetLifecyclePolicy",
      "ecr:GetRepositoryPolicy",
      "ecr:ListTagsForResource",
      "ecr:PutLifecyclePolicy",
      "ecr:TagResource",
      "ecr:UntagResource"
    ]

    resources = [
      "arn:aws:ecr:${var.aws_region}:*:repository/${var.project_name}-prod-app"
    ]
  }

  # Allows GitHub Actions to request the temporary ECR authentication token required by Docker.
  statement {
    sid    = "ECRAuthentication"
    effect = "Allow"

    actions = [
      "ecr:GetAuthorizationToken"
    ]

    resources = ["*"]
  }

  # Allows GitHub Actions to push and inspect images only in this project's production ECR repository.
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

  # Allows Terraform to manage the Application Load Balancer, listener and target group.
  # Allows Terraform to inspect ALB resources because ELB describe APIs are not resource-scoped.
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

  # Allows Terraform to manage only this project's ALB, listener and target group.
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

  # Allows Terraform to configure ECS Service Auto Scaling.
  # Allows Terraform to inspect ECS scaling configuration because describe APIs are not resource-scoped.
  statement {
    sid    = "DescribeAutoScaling"
    effect = "Allow"

    actions = [
      "application-autoscaling:DescribeScalableTargets",
      "application-autoscaling:DescribeScalingPolicies"
    ]

    resources = ["*"]
  }

  # Allows Terraform to manage only ECS scalable targets for this deployment.
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

    # Restricts scaling changes to ECS service desired-count targets.
    condition {
      test     = "StringEquals"
      variable = "application-autoscaling:service-namespace"

      values = [
        "ecs"
      ]
    }

    # Restricts scaling changes to the ECS service desired-count dimension.
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

  # Allows Terraform to discover CloudWatch log groups because this API is not resource-scoped.
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

  # Allows Terraform to read alarm state because DescribeAlarms is account-scoped.
  statement {
    sid    = "DescribeCloudWatchAlarms"
    effect = "Allow"

    actions = [
      "cloudwatch:DescribeAlarms"
    ]

    resources = ["*"]
  }

  # Allows Terraform to manage only the ECS IAM roles created for this production platform.
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
      "arn:aws:iam::*:role/ec2-to-ecs-migration-prod-ecs-execution-role",
      "arn:aws:iam::*:role/ec2-to-ecs-migration-prod-ecs-task-role"
    ]
  }

  # Allows Terraform to manage only the dedicated IAM role used by VPC Flow Logs.
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
      "arn:aws:iam::*:role/ec2-to-ecs-migration-prod-vpc-flow-logs-role"
    ]
  }

  # Allows Terraform to inspect the AWS-managed policy attached to the ECS execution role.
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

  # Allows only the project's ECS roles to be passed to the ECS tasks service.
  statement {
    sid    = "PassECSRoles"
    effect = "Allow"

    actions = [
      "iam:PassRole"
    ]

    resources = [
      "arn:aws:iam::*:role/ec2-to-ecs-migration-prod-ecs-execution-role",
      "arn:aws:iam::*:role/ec2-to-ecs-migration-prod-ecs-task-role"
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"

      values = [
        "ecs-tasks.amazonaws.com"
      ]
    }
  }

  # Allows Terraform to pass only the VPC Flow Logs role to the Flow Logs service.
  statement {
    sid    = "PassVPCFlowLogsRole"
    effect = "Allow"

    actions = [
      "iam:PassRole"
    ]

    resources = [
      "arn:aws:iam::*:role/ec2-to-ecs-migration-prod-vpc-flow-logs-role"
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"

      values = [
        "vpc-flow-logs.amazonaws.com"
      ]
    }
  }

  # Allows GitHub Actions to discover the Terraform state bucket without listing AWS buckets.
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

# Creates the customer-managed IAM policy used by the GitHub deployment role.
resource "aws_iam_policy" "github_actions" {
  name        = "${var.project_name}-github-actions"
  description = "Permissions used by GitHub Actions to deploy the ECS migration platform"

  policy = data.aws_iam_policy_document.github_actions_permissions.json
}

# Attaches the deployment permissions to the GitHub Actions OIDC role.
resource "aws_iam_role_policy_attachment" "github_actions" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions.arn
}