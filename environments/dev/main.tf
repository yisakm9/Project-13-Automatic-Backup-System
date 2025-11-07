 # Resource to generate a unique suffix for S3 buckets
resource "random_pet" "suffix" {
  length = 2
}

module "s3_backup_buckets" {
  source = "../../modules/s3_backup_buckets"

  primary_bucket_name = "${var.project_name}-primary-${var.environment}-${random_pet.suffix.id}"
  replica_bucket_name = "${var.project_name}-replica-${var.environment}-${random_pet.suffix.id}"
  aws_region_replica  = var.aws_region_replica

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}