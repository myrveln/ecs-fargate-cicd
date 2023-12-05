data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_ecr_repository" "this" {
  name                 = var.application_name
  image_tag_mutability = "MUTABLE"

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.this.arn
  }

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository_policy" "this" {
  repository = aws_ecr_repository.this.name
  policy     = data.aws_iam_policy_document.ecr.json
}

data "aws_iam_policy_document" "ecr" {
  statement {
    sid    = "ECRPull"
    effect = "Allow"

    principals {
      identifiers = [
        var.account_b
      ]
      type = "AWS"
    }

    actions = [
      "ecr:Get*",
      "ecr:List*",
      "ecr:Describe*",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability"
    ]
  }

  statement {
    sid    = "CodeBuildPush"
    effect = "Allow"

    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer"
    ]

    principals {
      identifiers = [ "codebuild.amazonaws.com" ]
      type = "Service"
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [ "arn:aws:codebuild:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:project/${var.application_name}" ]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [ data.aws_caller_identity.current.account_id ]
    }
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "keep last 5 images"
      action       = {
        type = "expire"
      }
      selection     = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
    }]
  })
}

resource "aws_kms_key" "this" {
  key_usage               = "ENCRYPT_DECRYPT"
  deletion_window_in_days = 30
  is_enabled              = true
  enable_key_rotation     = true
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.application_name}/ecr"
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
