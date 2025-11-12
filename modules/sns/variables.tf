variable "topic_name" {
  description = "The name of the SNS topic."
  type        = string
}
variable "kms_key_arn" {
  description = "The ARN of the customer-managed KMS key to use for SNS encryption. If null, uses AWS-managed key."
  type        = string
  default     = null
}
variable "tags" {
  description = "A map of tags to assign to the resources."
  type        = map(string)
  default     = {}
}