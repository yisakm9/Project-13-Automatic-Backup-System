# Description: Variables for the generic Lambda IAM role module.

variable "role_name" {
  description = "The name of the IAM role to create."
  type        = string
}

variable "s3_read_bucket_arns" {
  description = "A list of S3 bucket ARNs from which the Lambda function needs read access."
  type        = list(string)
  default     = []
}

variable "sqs_consume_queue_arns" {
  description = "A list of SQS queue ARNs from which the Lambda function can consume messages."
  type        = list(string)
  default     = []
}

variable "sns_publish_topic_arns" {
  description = "A list of SNS topic ARNs to which the Lambda function can publish messages."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "A map of tags to assign to the resources."
  type        = map(string)
  default     = {}
}