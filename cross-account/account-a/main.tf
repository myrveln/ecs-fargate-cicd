module "ecr" {
  source = "./modules/ecr"

  application_name    = var.application_name
  account_b           = var.account_b
}

module "codebuild" {
  source = "./modules/codebuild"

  account_b        = var.account_b
  application_name = var.application_name
  github_repo_url  = var.github_repo_url
  ecs_cluster      = var.application_name
  kms_key_arn      = module.codepipeline.kms_key_arn
}

module "codepipeline" {
  source = "./modules/codepipeline"

  account_b                        = var.account_b
  service_name                     = var.application_name
  ecr_repo_arn                     = module.ecr.repository_arn
  codedeploy_app_name              = var.application_name
  codedeploy_deployment_group_name = "${var.application_name}-deployment-group"
  codebuild_project_name           = module.codebuild.project_name
  github_repo_id                   = var.github_repo_id
  github_branch                    = var.github_branch
}
