data "aws_caller_identity" "current" {}

resource "aws_security_group" "alb" {
  name        = "${var.application_name}-alb-sg"
  description = "Allow ${var.application_name} traffic"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.application_name}-allow-http"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb" {
  security_group_id = aws_security_group.alb.id

  description = "Allow inbound HTTP"
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb" {
  security_group_id = aws_security_group.alb.id

  description                  = "Allow HTTP outbound"
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.service.id
}

resource "aws_lb" "public" {
  name               = "${var.application_name}-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.public_subnets
  security_groups    = [aws_security_group.alb.id]

  tags = {
    Name = "${var.application_name}-alb"
  }
}

resource "aws_lb_target_group" "blue" {
  name        = "${var.application_name}-target-group-blue"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path     = "/"
    port     = 80
    protocol = "HTTP"
  }
}

resource "aws_lb_target_group" "green" {
  name        = "${var.application_name}-target-group-green"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path     = "/"
    port     = 80
    protocol = "HTTP"
  }
}

resource "aws_lb_listener" "this" {
  load_balancer_arn = aws_lb.public.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.blue.arn
  }

  lifecycle {
    ignore_changes = [default_action]
  }
}

resource "aws_security_group" "service" {
  name        = "${var.application_name}-sg"
  description = "Allow ${var.application_name} traffic from ALB"

  vpc_id = var.vpc_id

  tags = {
    Name = "${var.application_name}-allow-http"
  }
}

resource "aws_vpc_security_group_ingress_rule" "service" {
  security_group_id = aws_security_group.service.id

  description                  = "Allow HTTP from ALB"
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.alb.id
}

resource "aws_vpc_security_group_egress_rule" "service" {
  security_group_id = aws_security_group.service.id

  description = "Allow outbound connections"
  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}

resource "aws_ecs_cluster" "this" {
  name = var.application_name

  setting {
    name = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_service" "this" {
  name            = var.application_name
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.service_desired_count
  launch_type     = "FARGATE"

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  # capacity_provider_strategy {
  #   base = 0
  #   capacity_provider = "FARGATE"
  #   weight = 100
  # }

  network_configuration {
    subnets         = var.private_subnets
    security_groups = [aws_security_group.service.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.blue.arn
    container_name   = var.application_name
    container_port   = 80
  }

  lifecycle {
    ignore_changes = [
      load_balancer,
      task_definition,
      desired_count
    ]
  }
}

resource "aws_iam_role" "execution_role" {
  name = "${var.application_name}-task-execution-role"

  assume_role_policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow"
        Principal : {
          Service : "ecs-tasks.amazonaws.com"
        }
        Action : "sts:AssumeRole"
      }
    ]
  })

  inline_policy {
    name = "TaskPolicy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          Effect   = "Allow"
          Resource = "*"
        },
        {
          Action = [
            "ecr:GetAuthorizationToken"
          ]
          Effect   = "Allow"
          Resource = "*"
        },
        {
          Action = [
            "ecr:BatchCheckLayerAvailability",
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage"
          ]
          Effect   = "Allow"
          Resource = "arn:aws:ecr:${var.region}:${data.aws_caller_identity.current.account_id}:repository/${var.application_name}"
        },
      ]
    })
  }
}

resource "aws_ecs_task_definition" "this" {
  family                   = var.application_name
  execution_role_arn       = aws_iam_role.execution_role.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu
  memory                   = var.memory

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "ARM64"
  }

  container_definitions = jsonencode([
    {
      name  = var.application_name
      image = "public.ecr.aws/nginx/nginx:alpine-slim"
      essential = true

      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ],

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${var.application_name}"
          awslogs-region        = var.region
          awslogs-stream-prefix = var.application_name
        }
      }
    }
  ])
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/ecs/${var.application_name}"
  retention_in_days = 7
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
        "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      ]
    }
  }
}

resource "aws_ecr_repository" "this" {
  name                 = var.application_name
  #image_tag_mutability = "IMMUTABLE"
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
    sid    = "ElasticContainerRegistryPushAndPull"
    effect = "Allow"

    principals {
      identifiers = [data.aws_caller_identity.current.account_id]
      type        = "AWS"
    }

    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
    ]
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

resource "aws_appautoscaling_target" "this" {
  max_capacity = var.task_max_capacity
  min_capacity = var.task_min_capacity
  resource_id = "service/${aws_ecs_cluster.this.name}/${aws_ecs_service.this.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace = "ecs"
}

resource "aws_appautoscaling_policy" "memory" {
  name               = "${var.application_name}-MemScaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.this.resource_id
  scalable_dimension = aws_appautoscaling_target.this.scalable_dimension
  service_namespace  = aws_appautoscaling_target.this.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }
    target_value = var.mem_threshold
  }
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.application_name}-CpuScaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.this.resource_id
  scalable_dimension = aws_appautoscaling_target.this.scalable_dimension
  service_namespace  = aws_appautoscaling_target.this.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = var.cpu_threshold
  }
}
