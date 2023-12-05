variable "account_b" {
  description = "The account ID of the application account."
  type        = string
}

variable "application_name" {
  description = "Name of the application you want to deploy on ECS"
  type        = string
}

variable "github_repo_url" {
  type        = string
}

variable "github_repo_id" {
  type        = string
}

variable "github_branch" {
  type        = string
}
