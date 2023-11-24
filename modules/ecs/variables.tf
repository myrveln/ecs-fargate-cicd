variable "vpc_id" {
  description = "ID of the VPC where your resources will be placed in"
  type        = string
}

variable "public_subnets" {
  description = "Id of the public subnets for the internet-facing ALB"
  type        = list(string)
}

variable "private_subnets" {
  type = list(string)
}

variable "service_desired_count" {
  type    = number
  default = 1
}

variable "region" {
  description = "AWS Region"
  type        = string
}

variable "application_name" {
  type = string
}

variable "memory" {
  description = "The amount (in MiB) of memory to present to the container"
  type        = number
  default     = 512
}

variable "cpu" {
  description = "The number of cpu units reserved for the container"
  type        = number
  default     = 256
}

variable "task_max_capacity" {
  description = ""
  type        = number
}
variable "task_min_capacity" {
  description = ""
  type        = number
}

variable "mem_threshold" {
  description = ""
  type        = number
}
variable "cpu_threshold" {
  description = ""
  type        = number
}
