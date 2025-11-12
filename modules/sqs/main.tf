# Description: Main configuration for the SQS module.
# Creates an SQS queue and a corresponding Dead-Letter Queue (DLQ).

resource "aws_sqs_queue" "dead_letter_queue" {
  name = var.dlq_name
  tags = var.tags
  kms_master_key_id = var.kms_key_arn
}

resource "aws_sqs_queue" "main_queue" {
  name                      = var.queue_name
  delay_seconds             = 0
  max_message_size          = 262144 # 256 KB
  message_retention_seconds = 345600   # 4 days
  visibility_timeout_seconds = 300      # 5 minutes
  # UPDATED: Use the passed-in KMS key ARN
  kms_master_key_id          = var.kms_key_arn
  kms_data_key_reuse_period_seconds = 300
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dead_letter_queue.arn
    maxReceiveCount     = var.max_receive_count
  })
   tags = merge(var.tags, {
    "RedrivePolicyEnforced" = "true" 
  })
}