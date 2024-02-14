variable "region" {
  type        = string
  description = "The AWS region where resources will be created."
}

variable "vpc_cidr_block" {
  type        = string
  description = "The CIDR block for the VPC. This defines the IP address range of the VPC."
}

variable "vpc_cidr_tag" {
  type        = string
  description = "The CIDR block for the VPC. This defines the tag for it."
}

variable "public_subnet_tag" {
  type        = string
  description = "Public subnet tag string"
}

variable "internet_gateway_tag" {
  type        = string
  description = "Internet gateway tag string"
}

variable "epi_tag" {
  type        = string
  description = "EPI tag string"
}

variable "route_table_tag" {
  type        = string
  description = "Route table tag string"
}

variable "ecs_cluster_name" {
  type        = string
  description = "ECS cluster name string"
}

variable "security_groups_name" {
  type        = string
  description = "ECS cluster name string"
}

variable "launch_template_name" {
  type        = string
  description = "Launch template name string"
}

variable "launch_template_instance_type" {
  type        = string
  description = "Launch template instance type"
}

variable "auto_scaling_group_name" {
  type        = string
  description = "Auto scaling group name string"
}

variable "auto_scaling_group_min_size" {
  type        = number
  description = "Auto scaling group minimum size"
}

variable "auto_scaling_group_max_size" {
  type        = number
  description = "Auto scaling group maximum size"
}

variable "ecs_capacity_provider_name" {
  type        = string
  description = "ECS capacity provider name string"
}

variable "ecs_task_definition_family_name" {
  type        = string
  description = "ecs task definition family name string"
}

variable "ecs_task_definition_family_cpu" {
  type        = number
  description = "ecs task definition family cpu"
}

variable "ecs_task_definition_family_memory" {
  type        = number
  description = "ecs task definition family memory"
}

variable "ecs_service_name" {
  type        = string
  description = "ecs service name string"
}

variable "ecs_alb_name" {
  type        = string
  description = "ecs application load balancer name string"
}