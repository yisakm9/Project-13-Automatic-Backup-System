# Description: Input variables for the 'dev' environment.

variable "aws_region_primary" {
  description = "The primary AWS region for deploying resources."
  type        = string
  default     = "us-east-1"
}

variable "aws_region_replica" {
  description = "The replica AWS region for disaster recovery."
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "The overall project name."
  type        = string
  default     = "autobackup"
}

variable "environment" {
  description = "The deployment environment (e.g., dev, prod)."
  type        = string
  default     = "dev"
}