terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "midigen-tf-state"
    key            = "github_oidc/terraform.tfstate"
    region         = "us-east-1"
    use_lockfile   = true
    encrypt        = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "midigen"
      ManagedBy = "terraform"
      Component = "github-oidc"
    }
  }
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "github_org" {
  type        = string
  description = "Your GitHub username or organization (e.g. 'hubertjanicki')"
}

variable "github_repo" {
  type        = string
  description = "Repository name (e.g. 'midi-generator-api')"
}

variable "allowed_branches" {
  type    = list(string)
  default = ["main"]
}

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_policy_document" "github_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        for branch in var.allowed_branches :
        "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/${branch}"
      ]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "midigen-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_trust.json
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "github_actions_deploy" {
  statement {
    sid     = "ECRAuth"
    actions = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid = "ECRPush"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = [
      "arn:aws:ecr:${var.region}:${data.aws_caller_identity.current.account_id}:repository/midigen-*-api"
    ]
  }

  statement {
    sid = "ECSTaskDefinition"
    actions = [
      "ecs:DescribeTaskDefinition",
      "ecs:RegisterTaskDefinition",
    ]
    resources = ["*"]  # te akcje wymagają "*" - nie da się ograniczyć
  }

  statement {
    sid = "ECSDeploy"
    actions = [
      "ecs:UpdateService",
      "ecs:DescribeServices",
    ]
    resources = [
      "arn:aws:ecs:${var.region}:${data.aws_caller_identity.current.account_id}:service/midigen-*-cluster/midigen-*-service"
    ]
  }

  statement {
    sid     = "PassRoleToECS"
    actions = ["iam:PassRole"]
    resources = [
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/midigen-*-task-exec-role",
      "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/midigen-*-task-role",
    ]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "github_actions_deploy" {
  name   = "deploy"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_actions_deploy.json
}

output "role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "Put this in GitHub Actions workflow as role-to-assume"
}
