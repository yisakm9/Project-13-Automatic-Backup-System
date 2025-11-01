# Description: Variables for the S3 backup buckets module.

variable "primary_bucket_prefix" {
  description = "The prefix for the primary S3 bucket name. A random suffix will be appended to ensure uniqueness."
  type        = string
}

variable "replica_bucket_prefix" {
  description = "The prefix for the replica S3 bucket name. A random suffix will be appended."
  type        = string
}

variable "aws_region_replica" {
  description = "The AWS region where the replica bucket will be created for disaster recovery."
  type        = string
}

variable "transition_to_glacier_days" {
  description = "Number of days after which to transition noncurrent versions to Glacier Instant Retrieval."
  type        = number
  default     = 30
}

variable "expire_old_versions_days" {
  description = "Number of days after which to expire old object versions."
  type        = number
  default     = 365
}

variable "tags" {
  description = "A map of tags to assign to the resources."
  type        = map(string)
  default     = {}
}