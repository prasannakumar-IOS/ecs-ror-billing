variable "region" {
  type        = string
  description = "The AWS region where resources will be created."
}

variable "security_groups_name" {
  type        = string
  description = "ECS cluster name string."
}

variable "vpc_id" {
  type = string
}
