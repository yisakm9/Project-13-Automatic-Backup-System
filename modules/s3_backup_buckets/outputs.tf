# Description: Outputs for the s3_backup_buckets module

output "primary_bucket_id" {
  description = "The ID of the primary S3 bucket."
  value       = aws_s3_bucket.primary.id
}

output "primary_bucket_arn" {
  description = "The ARN of the primary S3 bucket."
  value       = aws_s3_bucket.primary.arn
}

output "replica_bucket_id" {
  description = "The ID of the replica S3 bucket."
  value       = aws_s3_bucket.replica.id
}

output "replica_bucket_arn" {
  description = "The ARN of the replica S3 bucket."
  value       = aws_s3_bucket.replica.arn
}