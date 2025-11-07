# Description: Outputs for the IAM module.

output "role_arn" {
  description = "The ARN of the created IAM role."
  value       = aws_iam_role.lambda_exec.arn
}

output "role_name" {
  description = "The Name of the created IAM role."
  value       = aws_iam_role.lambda_exec.name
}