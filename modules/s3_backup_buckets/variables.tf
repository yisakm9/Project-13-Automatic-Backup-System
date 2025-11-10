# Description: Variables for the s3_backup_buckets module

variable "primary_bucket_name" {
  description = "The name of the primary S3 bucket for backups."
  type        = string
}

variable "replica_bucket_name" {
  description = "The name of the replica S3 bucket in the secondary region."
  type        = string
}

variable "aws_region_replica" {
  description = "The AWS region for the replica bucket."
  type        = string
}

variable "transition_to_glacier_ir_days" {
  description = "Number of days after which to transition noncurrent object versions to Glacier Instant Retrieval."
  type        = number
  default     = 30
}

variable "expiration_days" {
  description = "Number of days after which to expire noncurrent object versions."
  type        = number
  default     = 365
}

variable "tags" {
  description = "A map of tags to assign to the resources."
  type        = map(string)
  default     = {}
}
variable "rule_id_prefix" {
  description = "A unique prefix for the replication and lifecycle rule IDs."
  type        = string
}
