data "aws_caller_identity" "current" {}
data "aws_region" "current" {}


data "aws_iam_policy_document" "allow_assume_role" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type        = "AWS"
      identifiers = ["${var.account_a}"]
    }
  }
}

data "aws_iam_policy_document" "codepipeline" {
  statement {
    sid    = "ECSPolicy"
    effect = "Allow"
    actions = [
      "ecs:RegisterTaskDefinition"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "CodeDeployPolicy"
    effect = "Allow"
    actions = [
      "codedeploy:CreateDeployment",
      "codedeploy:GetApplication",
      "codedeploy:GetApplicationRevision",
      "codedeploy:RegisterApplicationRevision",
      "codedeploy:GetDeploymentConfig",
      "codedeploy:GetDeployment"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "S3Policy"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketAcl",
      "s3:GetBucketLocation"
    ]
    resources = ["arn:aws:s3:::${var.application_name}-artifact-bucket/*"]
  }

  statement {
    sid    = "KMSExternal"
    effect = "Allow"
    actions = [
      "kms:Decrypt"
    ]
    resources = ["arn:aws:kms:${data.aws_region.current.name}:${var.account_a}:key/*"] # Might need to be specific ID?
  }

  statement {
    sid    = "PassRolePolicy"
    effect = "Allow"
    actions = [
      "iam:PassRole"
    ]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.application_name}-task-execution-role"]
  }
}

resource "aws_iam_role" "codepipeline_cross_account" {
  name                = "${var.application_name}-codepipeline-ca-role"
  assume_role_policy  = data.aws_iam_policy_document.allow_assume_role.json
  inline_policy {
    name   = "CodePipeline"
    policy = data.aws_iam_policy_document.codepipeline.json
  }
}

data "aws_iam_policy_document" "codebuild" {
  statement {
    sid    = "ECSPolicy"
    effect = "Allow"
    actions = [
      "ecs:DescribeTaskDefinition",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "codebuild_cross_account" {
  name                = "${var.application_name}-codebuild-ca-role"
  assume_role_policy  = data.aws_iam_policy_document.allow_assume_role.json
  inline_policy {
    name   = "CodeBuild"
    policy = data.aws_iam_policy_document.codebuild.json
  }
}
