# Description: Outputs for the 'dev' environment.

output "primary_document_bucket_id" {
  description = "The ID of the primary S3 bucket for documents."
  value       = module.s3_documents_buckets.primary_bucket_id
}

output "primary_media_bucket_id" {
  description = "The ID of the primary S3 bucket for images and videos."
  value       = module.s3_media_buckets.primary_bucket_id
}

output "primary_database_bucket_id" {
  description = "The ID of the primary S3 bucket for database backups."
  value       = module.s3_database_buckets.primary_bucket_id
}