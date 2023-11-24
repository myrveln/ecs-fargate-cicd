variable "service_name" {
  description = "Name of the service that will be deployed via Codedeploy"
  type        = string
}

variable "ecs_cluster" {
  description = "Name of the ECS cluster where your service will be deployed to"
  type        = string
}

variable "service_alb_listener_arn" {
  description = "ARN of the Service ALB Listener"
  type        = string
}

variable "service_blue_target_group_name" {
  description = "Name of the Blue target group"
  type        = string
}

variable "service_green_target_group_name" {
  description = "Name of the Green target group"
  type        = string
}
