# Data source to create a ZIP archive of the source code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = var.source_code_path
  output_path = "${path.module}/${var.function_name}.zip"
}

# Add these data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Lambda function resource
resource "aws_lambda_function" "this" {
  function_name    = var.function_name
  handler          = var.handler
  runtime          = var.runtime
  role             = var.iam_role_arn
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 60

# REMEDIATION for CKV_AWS_116
  dead_letter_config {
    target_arn = var.lambda_dlq_arn
  }

  # REMEDIATION for CKV_AWS_50
  tracing_config {
    mode = "Active"
  }

  # REMEDIATION for CKV_AWS_173
  kms_key_arn = "arn:aws:kms:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:alias/aws/lambda"

  # REMEDIATION for CKV_AWS_115
  reserved_concurrent_executions = var.reserved_concurrent_executions
  environment {
    variables = var.environment_variables
  }

  tags = var.tags 

   # Add data sources to get current region and account ID
  depends_on = [
    data.aws_region.current,
    data.aws_caller_identity.current
  ]
}

# SQS Event Source Mapping (the trigger)
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = var.sqs_trigger_arn
  function_name    = aws_lambda_function.this.arn
  batch_size       = 5 # Process up to 5 messages at a time
}