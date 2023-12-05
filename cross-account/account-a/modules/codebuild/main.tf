data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "codebuild" {
  statement {
    sid    = "S3Policy"
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketAcl",
      "s3:GetBucketLocation"
    ]
    resources = ["arn:aws:s3:::${var.application_name}-artifact-bucket/*"]
  }

  statement {
    sid    = "ECRGetAuthorizationToken"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ECRSpecific"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetRepositoryPolicy",
      "ecr:ListImages",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage"
    ]
    resources = ["arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/${var.application_name}"]
  }

  statement {
    sid    = "CWPolicy"
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = ["${aws_cloudwatch_log_group.this.arn}:*"]
  }

  statement {
    sid    = "KMSPolicy"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey"
    ]
    resources = [ "${var.kms_key_arn}" ]

    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = [ "s3.${data.aws_region.current.name}.amazonaws.com" ]
    }

    condition {
      test     = "StringEquals"
      variable = "kms:CallerAccount"
      values   = [ "${data.aws_caller_identity.current.account_id}" ]
    }
  }

  statement {
    sid    = "AllowAssumeRoleExternal"
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    resources = ["arn:aws:iam::${var.account_b}:role/${var.application_name}-codebuild-ca-role"]
  }
}

resource "aws_iam_role" "codebuild" {
  name = "${var.application_name}-codebuild-service-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "codebuild.amazonaws.com"
          ]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "codebuild" {
  name   = "${var.application_name}-codebuild-policy"
  role   = aws_iam_role.codebuild.id
  policy = data.aws_iam_policy_document.codebuild.json
}

resource "aws_codebuild_project" "this" {
  name                   = var.application_name
  description            = "Builds ${var.application_name} app"
  service_role           = aws_iam_role.codebuild.arn
  build_timeout          = "5"
  concurrent_build_limit = 1

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/amazonlinux2-aarch64-standard:3.0"
    type            = "ARM_CONTAINER"
    privileged_mode = true
    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }
    environment_variable {
      name  = "EXTERNAL_ACCOUNT_ID"
      value = var.account_b
    }
    environment_variable {
      name  = "APPLICATION_NAME"
      value = var.application_name
    }
  }
  source {
    type            = "GITHUB"
    location        = var.github_repo_url
    git_clone_depth = 0
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.this.name
      status     = "ENABLED"
    }
  }
}

resource "aws_cloudwatch_log_group" "this" {
  name = "/aws/codebuild/${var.application_name}"
  retention_in_days = 14
}
