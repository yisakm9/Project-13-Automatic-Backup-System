# Description: Main configuration for the KMS module.
# Creates a robust, customer-managed KMS key with a dynamic access policy.

# Data sources to get the current account ID and region for constructing ARNs
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# The KMS Key resource.
resource "aws_kms_key" "this" {
  description             = "KMS key for ${var.key_alias}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = var.tags

  # CORRECTED: The policy is now constructed using concat() and ternary operators that return
  # a list with one element on success, or an empty list on failure.
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = concat(
      [
        # Statement 1: Always allows the root user of the account full administrative control.
        {
          Sid    = "EnableIAMUserPermissions",
          Effect = "Allow",
          Principal = {
            AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
          },
          Action   = "kms:*",
          Resource = "*"
        }
      ],
      # Statement 2 (Conditional): Grants IAM roles usage permissions.
      length(var.iam_role_arns_for_usage) > 0 ? [
        {
          Sid    = "AllowIAMRolesToUseKey",
          Effect = "Allow",
          Principal = {
            AWS = var.iam_role_arns_for_usage
          },
          Action = [
            "kms:Encrypt",
            "kms:Decrypt",
            "kms:ReEncrypt*",
            "kms:GenerateDataKey*",
            "kms:DescribeKey"
          ],
          Resource = "*"
        }
      ] : [],
      # Statement 3 (Conditional): Grants AWS services usage permissions.
      length(var.service_principals_for_encryption) > 0 ? [
        {
          Sid    = "AllowServicePrincipalsToUseKey",
          Effect = "Allow",
          Principal = {
            Service = var.service_principals_for_encryption
          },
          Action = [
            "kms:GenerateDataKey",
            "kms:Decrypt",
            "kms:CreateGrant",
            "kms:ListGrants",
            "kms:RevokeGrant"
          ],
          Resource = "*"
        }
      ] : []
    )
  })
}

# The KMS Alias resource, which gives the key a friendly name.
resource "aws_kms_alias" "this" {
  name          = "alias/${var.key_alias}"
  target_key_id = aws_kms_key.this.key_id
}