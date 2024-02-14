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

variable "route_table_tag" {
  type        = string
  description = "Route table tag string."
}
