 # Resource to generate a unique suffix for S3 buckets
resource "random_pet" "suffix" {
  length = 2
}
provider "aws" {
  alias  = "replica"
  region = var.aws_region_replica
}
#  BUCKET DEFINITIONS 
# Instantiate the S3 module three times, one for each category.

module "s3_documents_buckets" {
  source = "../../modules/s3_backup_buckets"
 # Pass the replica provider to the module
  providers = {
    aws.replica = aws.replica
  }
  eventbridge_rule_arn = module.eventbridge_s3_trigger.rule_arn
  rule_id_prefix      = "documents"
  primary_bucket_name = "${var.project_name}-documents-primary-${var.environment}-${random_pet.suffix.id}"
  replica_bucket_name = "${var.project_name}-documents-replica-${var.environment}-${random_pet.suffix.id}"
  aws_region_replica  = var.aws_region_replica

  tags = { Project = var.project_name, Environment = var.environment, Category = "Documents", ManagedBy = "Terraform" }
}

module "s3_media_buckets" {
  source = "../../modules/s3_backup_buckets"
  providers = {
    aws.replica = aws.replica
  }
  eventbridge_rule_arn = module.eventbridge_s3_trigger.rule_arn
  rule_id_prefix      = "media"
  primary_bucket_name = "${var.project_name}-media-primary-${var.environment}-${random_pet.suffix.id}"
  replica_bucket_name = "${var.project_name}-media-replica-${var.environment}-${random_pet.suffix.id}"
  aws_region_replica  = var.aws_region_replica

  tags = { Project = var.project_name, Environment = var.environment, Category = "Media", ManagedBy = "Terraform" }
}

module "s3_database_buckets" {
  source = "../../modules/s3_backup_buckets"
  providers = {
    aws.replica = aws.replica
  }
  eventbridge_rule_arn = module.eventbridge_s3_trigger.rule_arn
  rule_id_prefix      = "database"
  primary_bucket_name = "${var.project_name}-database-primary-${var.environment}-${random_pet.suffix.id}"
  replica_bucket_name = "${var.project_name}-database-replica-${var.environment}-${random_pet.suffix.id}"
  aws_region_replica  = var.aws_region_replica

  tags = { Project = var.project_name, Environment = var.environment, Category = "Database", ManagedBy = "Terraform" }
}
# --- IAM ROLES ---
# Update IAM roles to have permissions across all new buckets.

module "iam_checksum_validator" {
  source    = "../../modules/iam"
  role_name = "${var.project_name}-checksum-validator-role-${var.environment}"

  # Use concat() to create a single list of all six bucket ARNs
  s3_read_bucket_arns = concat(
    [
      module.s3_documents_buckets.primary_bucket_arn,
      module.s3_media_buckets.primary_bucket_arn,
      module.s3_database_buckets.primary_bucket_arn,
    ],
    [
      module.s3_documents_buckets.replica_bucket_arn,
      module.s3_media_buckets.replica_bucket_arn,
      module.s3_database_buckets.replica_bucket_arn,
    ]
  )
  sqs_dlq_send_arns = [module.sqs_failure_queues.main_queue_arn]
  sqs_consume_queue_arns = [module.sqs_queues.main_queue_arn]
  tags                   = { Project = var.project_name, Environment = var.environment, ManagedBy = "Terraform" }
}

# IAM role for the Failure Notifier Lambda function
module "iam_failure_notifier" {
  source    = "../../modules/iam"
  role_name = "${var.project_name}-failure-notifier-role-${var.environment}"

  
  sqs_consume_queue_arns = [module.sqs_failure_queues.main_queue_arn]
  sns_publish_topic_arns = [module.sns_failure_topic.topic_arn]
  sqs_dlq_send_arns      = [module.sqs_failure_queues.dlq_arn]
  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# SQS queues for the workflow
module "sqs_queues" {
  source   = "../../modules/sqs"
  queue_name = "${var.project_name}-validation-queue-${var.environment}"
  dlq_name   = "${var.project_name}-validation-dlq-${var.environment}"
  kms_key_arn = module.kms_sqs_key.key_arn
  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

module "sqs_failure_queues" {
  source   = "../../modules/sqs"
  queue_name = "${var.project_name}-failure-queue-${var.environment}"
  dlq_name   = "${var.project_name}-failure-dlq-${var.environment}"
  kms_key_arn = module.kms_sqs_key.key_arn
  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# EventBridge rule to capture S3 uploads
module "eventbridge_s3_trigger" {
  source           = "../../modules/eventbridge"
  rule_name        = "${var.project_name}-s3-upload-trigger-${var.environment}"
  target_arn       = module.sqs_queues.main_queue_arn
  sqs_target_queue_url = module.sqs_queues.main_queue_id
  # Pass a list of all primary bucket ARNs to monitor
  event_source_arns = [
    module.s3_documents_buckets.primary_bucket_arn,
    module.s3_media_buckets.primary_bucket_arn,
    module.s3_database_buckets.primary_bucket_arn,
  ]
  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Deploy the Checksum Validator Lambda function
module "lambda_checksum_validator" {
  source           = "../../modules/lambda_functions"
  function_name    = "${var.project_name}-checksum-validator-${var.environment}"
  source_code_path = "${path.root}/../../src/checksum-validator" 
  iam_role_arn     = module.iam_checksum_validator.role_arn
  sqs_trigger_arn  = module.sqs_queues.main_queue_arn
  # REMEDIATION: Pass the failure queue as the Lambda's DLQ
  lambda_dlq_arn   = module.sqs_failure_queues.main_queue_arn

  environment_variables = {
    REPLICA_AWS_REGION = var.aws_region_replica
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
# Deploy the Failure Notifier Lambda function
module "lambda_failure_notifier" {
  source           = "../../modules/lambda_functions"
  function_name    = "${var.project_name}-failure-notifier-${var.environment}"
  source_code_path = "${path.root}/../../src/failure-notifier"
  iam_role_arn     = module.iam_failure_notifier.role_arn
  sqs_trigger_arn  = module.sqs_failure_queues.main_queue_arn
# REMEDIATION: Pass its own DLQ as the Lambda's DLQ
  lambda_dlq_arn   = module.sqs_failure_queues.dlq_arn
  environment_variables = {
    SNS_TOPIC_ARN = module.sns_failure_topic.topic_arn
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
# SNS Topic for failure notifications
module "sns_failure_topic" {
  source     = "../../modules/sns"
  topic_name = "${var.project_name}-failure-topic-${var.environment}"
  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# SNS Email Subscription for alerts
resource "aws_sns_topic_subscription" "email_target" {
  topic_arn = module.sns_failure_topic.topic_arn
  protocol  = "email"
  
  endpoint  = "yisakmesifin@gmail.com"
}
module "kms_sqs_key" {
  source    = "../../modules/kms"
  key_alias = "${var.project_name}-sqs-key-${var.environment}"
  
  # This is the critical part that grants EventBridge permission
  service_principals_for_encryption = ["events.amazonaws.com"]

  tags = { Project = var.project_name, Environment = var.environment, ManagedBy = "Terraform" }
}