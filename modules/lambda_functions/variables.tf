variable "function_name" {
  description = "Name of the Lambda function."
  type        = string
}

variable "source_code_path" {
  description = "The local path to the Lambda function's source code directory."
  type        = string
}

variable "handler" {
  description = "The handler for the Lambda function (e.g., main.handler)."
  type        = string
  default     = "main.handler"
}

variable "runtime" {
  description = "The runtime for the Lambda function (e.g., python3.11)."
  type        = string
  default     = "python3.11"
}

variable "iam_role_arn" {
  description = "The ARN of the IAM role for the Lambda function."
  type        = string
}

variable "sqs_trigger_arn" {
  description = "The ARN of the SQS queue to be used as a trigger."
  type        = string
}

variable "environment_variables" {
  description = "A map of environment variables for the Lambda function."
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "A map of tags to assign to the resources."
  type        = map(string)
  default     = {}
}