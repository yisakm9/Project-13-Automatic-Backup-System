# Description: Outputs for the EventBridge module.

output "rule_arn" {
  description = "The ARN of the EventBridge rule."
  value       = aws_cloudwatch_event_rule.s3_creation_rule.arn
}