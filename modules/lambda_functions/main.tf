# Data source to create a ZIP archive of the source code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = var.source_code_path
  output_path = "${path.module}/${var.function_name}.zip"
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