
module "codedeploy" {
  source                          = "./modules/codedeploy"
  account_a                       = var.account_a
  service_name                    = module.ecs.ecs_service_name
  ecs_cluster                     = module.ecs.ecs_cluster_name
  service_alb_listener_arn        = module.ecs.alb_listener_arn
  service_blue_target_group_name  = module.ecs.blue_target_group_name
  service_green_target_group_name = module.ecs.green_target_group_name
}

module "cross-account-roles" {
  source                          = "./modules/cross-account-roles"
  application_name                = var.application_name
  account_a                       = var.account_a
}

module "ecs" {
  source                          = "./modules/ecs"
  account_a                       = var.account_a
  application_name                = var.application_name
  vpc_id                          = var.vpc_id
  public_subnets                  = var.public_subnets
  private_subnets                 = var.private_subnets
  task_max_capacity               = 6
  task_min_capacity               = 1
  mem_threshold                   = 80
  cpu_threshold                   = 65
}
