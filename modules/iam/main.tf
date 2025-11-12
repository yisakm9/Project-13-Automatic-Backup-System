# Description: Main configuration for the IAM module.
# This module creates a flexible IAM role for Lambda functions with conditionally attached policies.

# IAM Role for Lambda Functions
resource "aws_iam_role" "lambda_exec" {
  name               = var.role_name
  description        = "IAM role for ${var.role_name}"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
  tags = var.tags
}

# Base policy for CloudWatch Logs (all Lambdas need this)
resource "aws_iam_policy" "cloudwatch_logs" {
  name        = "${var.role_name}-cloudwatch-logs-policy"
  description = "Allows Lambda function to write to CloudWatch Logs."
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.cloudwatch_logs.arn
}

# Conditional policy for S3 read access
resource "aws_iam_policy" "s3_read" {
  count       = length(var.s3_read_bucket_arns) > 0 ? 1 : 0
  name        = "${var.role_name}-s3-read-policy"
  description = "Allows read access to specified S3 buckets."
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      # Allows actions on the objects themselves (e.g., get, head)
      {
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:HeadObject" 
        ]
        Effect   = "Allow"
        Resource = [for arn in var.s3_read_bucket_arns : "${arn}/*"]
      },
      # Allows listing the contents of the buckets
      {
        Action   = "s3:ListBucket"
        Effect   = "Allow"
        Resource = var.s3_read_bucket_arns
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "s3_read" {
  count      = length(var.s3_read_bucket_arns) > 0 ? 1 : 0
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.s3_read[0].arn
}

# Conditional policy for SQS consume access
resource "aws_iam_policy" "sqs_consume" {
  count       = length(var.sqs_consume_queue_arns) > 0 ? 1 : 0
  name        = "${var.role_name}-sqs-consume-policy"
  description = "Allows consuming messages from specified SQS queues."
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Effect   = "Allow"
        Resource = var.sqs_consume_queue_arns
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sqs_consume" {
  count      = length(var.sqs_consume_queue_arns) > 0 ? 1 : 0
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.sqs_consume[0].arn
}

# Conditional policy for SNS publish access
resource "aws_iam_policy" "sns_publish" {
  count       = length(var.sns_publish_topic_arns) > 0 ? 1 : 0
  name        = "${var.role_name}-sns-publish-policy"
  description = "Allows publishing to specified SNS topics."
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action   = "sns:Publish"
        Effect   = "Allow"
        Resource = var.sns_publish_topic_arns
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sns_publish" {
  count      = length(var.sns_publish_topic_arns) > 0 ? 1 : 0
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.sns_publish[0].arn
}

# Conditional policy for SQS DLQ send access
resource "aws_iam_policy" "sqs_dlq_send" {
  count       = length(var.sqs_dlq_send_arns) > 0 ? 1 : 0
  name        = "${var.role_name}-sqs-dlq-send-policy"
  description = "Allows sending messages to specified SQS queues for DLQ."
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Action   = "sqs:SendMessage"
        Effect   = "Allow"
        Resource = var.sqs_dlq_send_arns
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sqs_dlq_send" {
  count      = length(var.sqs_dlq_send_arns) > 0 ? 1 : 0
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.sqs_dlq_send[0].arn
}