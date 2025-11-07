# Description: Main configuration for the EventBridge module.
# Creates a rule to listen for S3 Object Created events and target an SQS queue.

resource "aws_cloudwatch_event_rule" "s3_creation_rule" {
  name        = var.rule_name
  description = "Captures S3 ObjectCreated events from the primary backup bucket."
  event_pattern = jsonencode({
    "source" : ["aws.s3"],
    "detail-type" : ["Object Created"],
    "resources" : [var.event_source_arn]
  })
  tags = var.tags
}

resource "aws_cloudwatch_event_target" "sqs_queue" {
  rule      = aws_cloudwatch_event_rule.s3_creation_rule.name
  target_id = "SendToValidationQueue"
  arn       = var.target_arn
}

# IAM policy to allow EventBridge to send messages to the SQS queue
resource "aws_sqs_queue_policy" "eventbridge_to_sqs" {
  
  queue_url = var.sqs_target_queue_url
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { "Service" : "events.amazonaws.com" },
        Action    = "sqs:SendMessage",
        Resource  = var.target_arn, 
        Condition = {
          ArnEquals = { "aws:SourceArn" = aws_cloudwatch_event_rule.s3_creation_rule.arn }
        }
      }
    ]
  })
}