# Data source to create a ZIP archive of the source code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = var.source_code_path
  output_path = "${path.module}/${var.function_name}.zip"
}
data "aws_kms_alias" "lambda_key" {
  name = "alias/aws/lambda"
}

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
 # Use the resolved Key ARN from the data source
  kms_key_arn = data.aws_kms_alias.lambda_key.target_key_arn

  # REMEDIATION for CKV_AWS_115
  # reserved_concurrent_executions = var.reserved_concurrent_executions
  environment {
    variables = var.environment_variables
  }

  tags = var.tags 

   
}

# SQS Event Source Mapping (the trigger)
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = var.sqs_trigger_arn
  function_name    = aws_lambda_function.this.arn
  batch_size       = 5 # Process up to 5 messages at a time
}