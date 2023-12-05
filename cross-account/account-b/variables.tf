variable "account_a" {
  description = "The account ID of the shared account."
  type        = string
}

variable "application_name" {
  description = "Name of the application you want to deploy on ECS"
  type        = string
}

variable "vpc_id" {
  description = "Id of the VPC where the Service will be deployed into"
  type        = string
}

variable "public_subnets" {
  description = "Id of the public subnets for the internet-facing ALB"
  type        = list(string)
}

variable "private_subnets" {
  description = "Id of the private subnets for the ECS service"
  type        = list(string)
}
