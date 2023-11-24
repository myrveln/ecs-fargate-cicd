variable "aws_region" {
  description = "AWS Region"
  type        = string
  default     = "eu-north-1"
}

variable "application_name" {
  description = "Name of the application you want to deploy on ECS"
  type        = string
  default     = "docker-sample"
}

variable "vpc_id" {
  description = "Id of the VPC where the Service will be deployed into"
  type        = string
  default     = "vpc-052782e882c202589"
}

variable "public_subnets" {
  description = "Id of the public subnets for the internet-facing ALB"
  type        = list(string)
  default     = ["subnet-08f6268cee002a39c", "subnet-0b82470e32adaa4e0"]
}

variable "private_subnets" {
  description = "Id of the private subnets for the ECS service"
  type        = list(string)
  default     = ["subnet-0dde13227f78d8c49", "subnet-035704e626881e69a"]
}

variable "github_repo_id" {
  description = "Id of the Github repository (e.g. <owner>/<repository-name>)"
  type        = string
  default     = "myrveln/docker-sample"
}

variable "github_repo_url" {
  description = "URL of the Git repository"
  type        = string
  default     = "https://github.com/myrveln/docker-sample.git"
}

variable "github_branch" {
  description = "Git branch that stores the code of the service"
  type        = string
  default     = "master"
}
