data "aws_caller_identity" "current" {}

resource "aws_codestarconnections_connection" "github" {
  name          = "github-connection"
  provider_type = "GitHub"
}

resource "aws_iam_role" "codepipeline" {
  name = "${var.service_name}-codepipeline-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "codepipeline.amazonaws.com"
          ]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

data "aws_iam_policy_document" "codepipeline" {
  statement {
    sid    = "AccessToArtifactBucket"
    effect = "Allow"
    actions = [
      "s3:Get*",
      "s3:Put*",
      "s3:ListBucket"
    ]
    resources = [
      "${aws_s3_bucket.this.arn}",
      "${aws_s3_bucket.this.arn}/*"
    ]
  }

  statement {
    sid    = "CodeStarConnectionsPolicy"
    effect = "Allow"
    actions = [
      "codestar-connections:UseConnection"
    ]
    resources = [
      aws_codestarconnections_connection.github.arn
    ]
  }

  statement {
    sid    = "CodeBuildPolicy"
    effect = "Allow"
    actions = [
      "codebuild:*"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "KMSPolicy"
    effect = "Allow"
    actions = [
      "kms:GenerateDataKey",
      "kms:Decrypt"
    ]
    resources = [
      aws_kms_key.this.arn
    ]
  }

  statement {
    sid    = "AllowAssumeRoleExternal"
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    resources = ["arn:aws:iam::${var.account_b}:role/${var.service_name}-codepipeline-ca-role"]
  }

}

resource "aws_iam_policy" "codepipeline" {
  name   = "${var.service_name}-codepipeline-policy"
  policy = data.aws_iam_policy_document.codepipeline.json
}

resource "aws_iam_role_policy_attachment" "this" {
  role       = aws_iam_role.codepipeline.name
  policy_arn = aws_iam_policy.codepipeline.arn
}

resource "aws_codepipeline" "this" {
  name     = "${var.service_name}-pipeline"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = aws_s3_bucket.this.id
    type     = "S3"

    encryption_key {
      id   = aws_kms_key.this.id
      type = "KMS"
    }
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["SourceArtifact"]

      configuration = {
        ConnectionArn        = aws_codestarconnections_connection.github.arn
        FullRepositoryId     = var.github_repo_id
        BranchName           = var.github_branch
        OutputArtifactFormat = "CODE_ZIP"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["BuildArtifact"]

      configuration = {
        ProjectName = var.codebuild_project_name
      }
    }
  }

  # IMPORTANT!
  # Uncomment this when account-b has run, and created the role
  # stage {
  #   name = "Deploy"

  #   action {
  #     name            = "Deploy"
  #     category        = "Deploy"
  #     owner           = "AWS"
  #     provider        = "CodeDeployToECS"
  #     version         = "1"
  #     input_artifacts = ["BuildArtifact"]
  #     role_arn        = "arn:aws:iam::${var.account_b}:role/${var.service_name}-codepipeline-ca-role"

  #     configuration = {
  #       ApplicationName                = var.codedeploy_app_name
  #       DeploymentGroupName            = var.codedeploy_deployment_group_name
  #       TaskDefinitionTemplateArtifact = "BuildArtifact"
  #       TaskDefinitionTemplatePath     = "taskdef.json"
  #       AppSpecTemplateArtifact        = "BuildArtifact"
  #       AppSpecTemplatePath            = "appspec.yml"
  #     }
  #   }
  # }
}

resource "aws_s3_bucket" "this" {
  bucket = "${var.service_name}-artifact-bucket"
  force_destroy = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.this.arn
      sse_algorithm     = "aws:kms"
    }

    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.id
  policy = data.aws_iam_policy_document.s3.json
}

data "aws_iam_policy_document" "s3" {
  statement {
    sid = "DenyUnEncryptedObjectUploads"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = [
      "s3:PutObject"
    ]
    resources = [
      "${aws_s3_bucket.this.arn}/*"
    ]
    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = [ "aws:kms" ]
    }
  }

  statement {
    sid = "DenyInsecureConnections"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = [
      "s3:*"
    ]
    resources = [
      "${aws_s3_bucket.this.arn}/*"
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = [ "false" ]
    }
  }

  statement {
    sid = "AllowGetAndPutExternal"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["${var.account_b}"]
    }
    actions = [
      "s3:Get*",
      "s3:Put*"
    ]
    resources = [
      "${aws_s3_bucket.this.arn}/*"
    ]
  }

  statement {
    sid = "AllowListExternal"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["${var.account_b}"]
    }
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      "${aws_s3_bucket.this.arn}"
    ]
  }
}

resource "aws_kms_key" "this" {
  key_usage               = "ENCRYPT_DECRYPT"
  deletion_window_in_days = 30
  is_enabled              = true
  enable_key_rotation     = true
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.service_name}/s3"
  target_key_id = aws_kms_key.this.key_id
}

resource "aws_kms_key_policy" "this" {
  key_id = aws_kms_key.this.id
  policy = data.aws_iam_policy_document.key_policy.json
}

data "aws_iam_policy_document" "key_policy" {
  statement {
    effect = "Allow"
    actions = [
      "kms:*"
    ]
    resources = ["*"]
    principals {
      type = "AWS"
      identifiers = [
        data.aws_caller_identity.current.account_id,
        var.account_b
      ]
    }
  }
}
