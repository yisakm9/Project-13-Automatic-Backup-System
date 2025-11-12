# Description: Main configuration for the EventBridge module.
# Creates a rule to listen for S3 Object Created events and target an SQS queue.

resource "aws_cloudwatch_event_rule" "s3_creation_rule" {
  name        = var.rule_name
  description = "Captures S3 ObjectCreated events from the primary backup bucket."
  event_pattern = jsonencode({
    "source" : ["aws.s3"],
    "detail-type" : ["Object Created"],
     "resources"   = var.event_source_arns
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

# This policy is crucial. It gives the S3 service principal permission to publish
# events to the default EventBridge bus, but scoped down to only allow events
# that originate from our specified source buckets.
resource "aws_cloudwatch_event_bus_policy" "s3_to_eventbridge" {
  event_bus_name = "default" # We are using the default event bus

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowS3ToPutEvents",
        Effect    = "Allow",
        Principal = {
          Service = "s3.amazonaws.com"
        },
        Action    = "events:PutEvents",
        Resource  = "arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:event-bus/default",
        Condition = {
          "ArnLike" = {
            "aws:SourceArn" = [for arn in var.event_source_arns : "${arn}"]
          }
        }
      }
    ]
  })

  # We add a dependency on the rule to ensure the policy isn't created in isolation.
  depends_on = [aws_cloudwatch_event_rule.s3_creation_rule]
}

# ADD THESE DATA SOURCES to construct the policy ARN dynamically
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}