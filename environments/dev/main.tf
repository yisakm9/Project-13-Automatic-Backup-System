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
# IAM role for the Checksum Validator Lambda function
module "iam_checksum_validator" {
  source    = "../../modules/iam"
  role_name = "${var.project_name}-checksum-validator-role-${var.environment}"

  s3_read_bucket_arns = [
    module.s3_backup_buckets.primary_bucket_arn,
    module.s3_backup_buckets.replica_bucket_arn
  ]

  # We will add SQS and SNS ARNs here in later phases
  # sqs_consume_queue_arns = [module.sqs.validation_queue_arn]

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# IAM role for the Failure Notifier Lambda function
module "iam_failure_notifier" {
  source    = "../../modules/iam"
  role_name = "${var.project_name}-failure-notifier-role-${var.environment}"

  # We will add SQS and SNS ARNs here in later phases
  # sqs_consume_queue_arns = [module.sqs.failure_queue_arn]
  # sns_publish_topic_arns = [module.sns.failure_topic_arn]

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}