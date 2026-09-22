# Registers GitHub Actions as a trusted OpenID Connect identity provider in AWS.
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]
}

# Builds the trust policy that allows only this repository's production environment to authenticate GitHub OIDC.
data "aws_iam_policy_document" "github_actions_trust" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type = "Federated"

      identifiers = [
        aws_iam_openid_connect_provider.github.arn
      ]
    }

    # Ensures the OIDC token was issued for AWS STS.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    # Restricts access to the production environment in this specific GitHub repository.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"

      values = [
        "repo:CloudRizz/ec2-to-ecs-migration:environment:production"
      ]
    }
  }
}

# Creates the AWS role that approved GitHub Actions deployments can assume.
resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-github-actions"

  assume_role_policy = data.aws_iam_policy_document.github_actions_trust.json

  tags = {
    Name    = "${var.project_name}-github-actions"
    Purpose = "GitHub Actions OIDC deployment role"
  }
}