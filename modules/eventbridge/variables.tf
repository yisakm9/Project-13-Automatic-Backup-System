# Description: Variables for the EventBridge rule module.

variable "rule_name" {
  description = "The name of the EventBridge rule."
  type        = string
}

variable "event_source_arn" {
  description = "The ARN of the resource that is the source of the event (e.g., S3 bucket ARN)."
  type        = string
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