# Description: Variables for the EventBridge rule module.

variable "rule_name" {
  description = "The name of the EventBridge rule."
  type        = string
}
variable "sqs_target_queue_url" {
  description = "The URL of the target SQS queue, required for setting the queue policy."
  type        = string
}
variable "event_source_arns" {
  description = "A list of ARNs for the resources that are the source of the event."
  type        = list(string)
}

variable "target_arn" {
  description = "The ARN of the target for the event (e.g., SQS queue ARN)."
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to the resources."
  type        = map(string)
  default     = {}
}