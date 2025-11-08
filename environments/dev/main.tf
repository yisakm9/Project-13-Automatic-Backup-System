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

  
  sqs_consume_queue_arns = [module.sqs_queues.main_queue_arn]

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

  
  sqs_consume_queue_arns = [module.sqs_failure_queues.main_queue_arn]
  sns_publish_topic_arns = [module.sns_failure_topic.topic_arn]

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
  event_source_arn = module.s3_backup_buckets.primary_bucket_arn
  target_arn       = module.sqs_queues.main_queue_arn

  sqs_target_queue_url = module.sqs_queues.main_queue_id

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