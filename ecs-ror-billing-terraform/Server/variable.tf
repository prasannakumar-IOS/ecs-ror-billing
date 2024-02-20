variable "region" {
  type        = string
  description = "The AWS region where resources will be created."
}

variable "ecs_cluster_name" {
  type        = string
  description = "ECS cluster name string."
}

variable "launch_template_name" {
  type        = string
  description = "Launch template name string."
}

variable "launch_template_instance_type" {
  type        = string
  description = "Launch template instance type."
}

variable "auto_scaling_group_name" {
  type        = string
  description = "Auto scaling group name string."
}

variable "auto_scaling_group_min_size" {
  type        = number
  description = "Auto scaling group minimum size."
}

variable "auto_scaling_group_max_size" {
  type        = number
  description = "Auto scaling group maximum size."
}

variable "ecs_capacity_provider_name" {
  type        = string
  description = "ECS capacity provider name string."
}

variable "ecs_task_definition_family_name" {
  type        = string
  description = "ecs task definition family name string."
}

variable "ecs_task_definition_family_cpu" {
  type        = number
  description = "ecs task definition family cpu."
}

variable "ecs_task_definition_family_memory" {
  type        = number
  description = "ecs task definition family memory."
}

variable "ecs_service_name" {
  type        = string
  description = "ecs service name string."
}

variable "ecs_alb_name" {
  type        = string
  description = "ecs application load balancer name string."
}
