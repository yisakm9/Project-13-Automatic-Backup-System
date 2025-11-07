# Description: Variables for the SQS queue module.

variable "queue_name" {
  description = "The name of the main SQS queue."
  type        = string
}

variable "dlq_name" {
  description = "The name of the Dead-Letter Queue (DLQ)."
  type        = string
}

variable "max_receive_count" {
  description = "The number of times a message is delivered to the source queue before being moved to the DLQ."
  type        = number
  default     = 3
}

variable "tags" {
  description = "A map of tags to assign to the resources."
  type        = map(string)
  default     = {}
}