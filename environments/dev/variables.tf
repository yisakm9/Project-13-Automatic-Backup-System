# Description: Variable definitions for the 'dev' environment.

variable "aws_region_primary" {
  description = "The primary AWS region for the dev environment."
  type        = string
  default     = "us-east-1"
}

variable "aws_region_replica" {
  description = "The replica AWS region for disaster recovery."
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "The name of the project."
  type        = string
  default     = "autobackup"
}

variable "environment" {
  description = "The environment name (e.g., dev, prod)."
  type        = string
  default     = "dev"
}