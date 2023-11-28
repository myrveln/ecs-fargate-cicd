variable "application_name" {
  description = "Name of the codebuild project"
  type        = string
}

variable "ecs_cluster" {
  description = "Name of the ECS Cluster where the service will be deployed"
  type        = string
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
}

variable "github_repo_url" {
  description = "Url of the Github repository that contains the application code"
  type        = string
}

variable "kms_key_arn" {
  type        = string
}

variable "task_arn" {
  type        = string
}
