variable "key_alias" {
  description = "The alias for the KMS key."
  type        = string
}

variable "service_principals_for_encryption" {
  description = "A list of AWS service principals that need permission to use this key for encryption (e.g., events.amazonaws.com)."
  type        = list(string)
  default     = []
}
variable "iam_role_arns_for_usage" {
  description = "A list of IAM Role ARNs that need permission to use this key."
  type        = list(string)
  default     = []
}
variable "tags" {
  description = "A map of tags to assign to the key."
  type        = map(string)
  default     = {}
}