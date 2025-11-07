# Description: Outputs for the 'dev' environment.

output "primary_bucket_id" {
  description = "The ID of the primary S3 bucket."
  value       = module.s3_backup_buckets.primary_bucket_id
}

output "replica_bucket_id" {
  description = "The ID of the replica S3 bucket."
  value       = module.s3_backup_buckets.replica_bucket_id
}