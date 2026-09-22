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
    sid    = "TerraformNetworking"
    effect = "Allow"

    actions = [
      "ec2:AllocateAddress",
      "ec2:AssociateRouteTable",
      "ec2:AttachInternetGateway",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CreateInternetGateway",
      "ec2:CreateNatGateway",
      "ec2:CreateRoute",
      "ec2:CreateRouteTable",
      "ec2:CreateSecurityGroup",
      "ec2:CreateSubnet",
      "ec2:CreateTags",
      "ec2:CreateVpc",
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

  # Allows Terraform to manage the ECS cluster, task definitions and Fargate service.
  statement {
    sid    = "TerraformECS"
    effect = "Allow"

    actions = [
      "ecs:CreateCluster",
      "ecs:CreateService",
      "ecs:DeleteCluster",
      "ecs:DeleteService",
      "ecs:DeregisterTaskDefinition",
      "ecs:DescribeClusters",
      "ecs:DescribeServices",
      "ecs:DescribeTaskDefinition",
      "ecs:ListServices",
      "ecs:ListTagsForResource",
      "ecs:ListTaskDefinitions",
      "ecs:RegisterTaskDefinition",
      "ecs:TagResource",
      "ecs:UntagResource",
      "ecs:UpdateService"
    ]

    resources = ["*"]
  }

  # Allows Terraform to manage the ECR repository and its lifecycle configuration.
  statement {
    sid    = "TerraformECR"
    effect = "Allow"

    actions = [
      "ecr:CreateRepository",
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

    resources = ["*"]
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
  statement {
    sid    = "TerraformELB"
    effect = "Allow"

    actions = [
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:DescribeListenerAttributes",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:DescribeLoadBalancerAttributes",
      "elasticloadbalancing:DescribeLoadBalancers",
      "elasticloadbalancing:DescribeTags",
      "elasticloadbalancing:DescribeTargetGroupAttributes",
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:RemoveTags"
    ]

    resources = ["*"]
  }

  # Allows Terraform to configure ECS Service Auto Scaling.
  statement {
    sid    = "TerraformAutoScaling"
    effect = "Allow"

    actions = [
      "application-autoscaling:DeleteScalingPolicy",
      "application-autoscaling:DeregisterScalableTarget",
      "application-autoscaling:DescribeScalableTargets",
      "application-autoscaling:DescribeScalingPolicies",
      "application-autoscaling:PutScalingPolicy",
      "application-autoscaling:RegisterScalableTarget",
      "application-autoscaling:TagResource",
      "application-autoscaling:UntagResource"
    ]

    resources = ["*"]
  }

  # Allows Terraform to manage application log groups and monitoring alarms.
  statement {
    sid    = "TerraformObservability"
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:DescribeLogGroups",
      "logs:ListTagsForResource",
      "logs:PutRetentionPolicy",
      "logs:TagResource",
      "logs:UntagResource",
      "cloudwatch:DeleteAlarms",
      "cloudwatch:DescribeAlarms",
      "cloudwatch:ListTagsForResource",
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:TagResource",
      "cloudwatch:UntagResource"
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