variable "service_name" {
  description = "Name of the service you want to deploy to ECS"
  type        = string
}

variable "ecr_repo_arn" {
  description = "ARN of the ECR repository where the image is stored"
  type        = string
}

variable "codedeploy_app_name" {
  description = "Name of the CodeDeploy App"
  type        = string
}

variable "codedeploy_app_arn" {
  description = "ARN of the CodeDeploy App"
  type        = string
}

variable "codedeploy_deployment_group_name" {
  description = "Name of the CodeDeploy deployment group"
  type        = string
}

variable "codedeploy_deployment_group_arn" {
  description = "ARN of the CodeDeploy deployment group"
  type        = string
}

variable "codebuild_project_name" {
  description = "Name of the CodeBuild project"
  type        = string
}

variable "github_repo_id" {
  description = "Id of the Github repository. (Ex. <owner>/<repository-name>)"
  type        = string
}

variable "github_branch" {
  description = "Github branch that will be used for deployment"
  type        = string
  default     = "main"
}
