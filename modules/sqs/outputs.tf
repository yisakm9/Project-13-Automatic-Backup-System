# Description: Outputs for the SQS module.

output "main_queue_arn" {
  description = "The ARN of the main SQS queue."
  value       = aws_sqs_queue.main_queue.arn
}

output "main_queue_id" {
  description = "The ID (URL) of the main SQS queue."
  value       = aws_sqs_queue.main_queue.id
}

output "dlq_arn" {
  description = "The ARN of the Dead-Letter Queue."
  value       = aws_sqs_queue.dead_letter_queue.arn
}