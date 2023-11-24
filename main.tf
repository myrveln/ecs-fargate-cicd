# Create ECS resources
module "ecs" {
  source = "./modules/ecs"

  application_name    = var.application_name
  region              = var.aws_region
  vpc_id              = var.vpc_id
  public_subnets      = var.public_subnets
  private_subnets     = var.private_subnets

  task_max_capacity   = 6
  task_min_capacity   = 1
  mem_threshold       = 80
  cpu_threshold       = 65
}

# Create codedeploy app and deployment group
module "codedeploy" {
  source = "./modules/codedeploy"

  service_name                    = module.ecs.ecs_service_name
  ecs_cluster                     = module.ecs.ecs_cluster_name
  service_alb_listener_arn        = module.ecs.alb_listener_arn
  service_blue_target_group_name  = module.ecs.blue_target_group_name
  service_green_target_group_name = module.ecs.green_target_group_name
}

# Create Codebuild project to build the docker image and push to ECR
module "codebuild" {
  source = "./modules/codebuild"

  application_name = var.application_name
  aws_region       = var.aws_region
  ecs_cluster      = module.ecs.ecs_cluster_name
  github_repo_url  = var.github_repo_url
  kms_key_arn      = module.codepipeline.kms_key_arn
}

# Create a pipeline in Codepipeline that calls Codebuild to build the image and
# deploy the service to ECS blue/green deployment
module "codepipeline" {
  source = "./modules/codepipeline"

  service_name                     = module.ecs.ecs_service_name
  ecr_repo_arn                     = module.ecs.ecr_repository_arn
  codedeploy_app_name              = module.codedeploy.app_name
  codedeploy_app_arn               = module.codedeploy.app_arn
  codedeploy_deployment_group_name = module.codedeploy.deployment_group_name
  codedeploy_deployment_group_arn  = module.codedeploy.deployment_group_arn
  codebuild_project_name           = module.codebuild.project_name
  github_repo_id                   = var.github_repo_id
  github_branch                    = var.github_branch
}
