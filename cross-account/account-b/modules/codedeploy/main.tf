data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "codedeploy" {
  statement {
    sid    = "ECSPolicy"
    effect = "Allow"
    actions = [
      "ecs:DescribeServices",
      "ecs:CreateTaskSet",
      "ecs:DeleteTaskSet",
      "ecs:UpdateServicePrimaryTaskSet"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ELBPolicy"
    effect = "Allow"
    actions = [
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeListeners",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:DescribeRules"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "PassRolePolicy"
    effect = "Allow"
    actions = [
      "iam:PassRole"
    ]
    resources = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${var.service_name}-task-execution-role"]
  }
}

resource "aws_iam_role" "codedeploy" {
  name = "${var.service_name}-codedeploy-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = [
            "codedeploy.amazonaws.com"
          ]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "codedeploy" {
  name   = "${var.service_name}-codedeploy-policy"
  role   = aws_iam_role.codedeploy.id
  policy = data.aws_iam_policy_document.codedeploy.json
}

resource "aws_codedeploy_app" "this" {
  compute_platform = "ECS"
  name             = var.service_name
}

resource "aws_codedeploy_deployment_group" "this" {
  app_name               = aws_codedeploy_app.this.name
  deployment_group_name  = "${var.service_name}-deployment-group"
  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
  service_role_arn       = aws_iam_role.codedeploy.arn

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  deployment_style {
    deployment_type   = "BLUE_GREEN"
    deployment_option = "WITH_TRAFFIC_CONTROL"
  }

  blue_green_deployment_config {
    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
    }

    terminate_blue_instances_on_deployment_success {
      action                           = "TERMINATE"
      termination_wait_time_in_minutes = 5
    }
  }

  ecs_service {
    service_name = var.service_name
    cluster_name = var.ecs_cluster
  }

  load_balancer_info {
    target_group_pair_info {
      prod_traffic_route {
        listener_arns = [var.service_alb_listener_arn]
      }

      target_group {
        name = var.service_blue_target_group_name
      }

      target_group {
        name = var.service_green_target_group_name
      }
    }
  }
}
