# Description: Main configuration for the KMS module.
# Creates a robust, customer-managed KMS key with a dynamic access policy.

# Data sources to get the current account ID and region for constructing ARNs
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# A locals block is used to cleanly and dynamically construct the list of policy statements.
# This avoids errors when one of the input variable lists is empty.
locals {
  policy_statements = [
    # Statement 1: Always allows the root user of the account full administrative control over the key.
    # This is a security best practice to prevent being locked out of your own key.
    {
      Sid    = "EnableIAMUserPermissions",
      Effect = "Allow",
      Principal = {
        AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
      },
      Action   = "kms:*",
      Resource = "*"
    },

    # Statement 2 (Conditional): This block is only included if the 'iam_role_arns_for_usage' variable is not empty.
    # It grants specified IAM Roles (like our Lambda execution roles) permission to use the key for cryptographic operations.
    length(var.iam_role_arns_for_usage) > 0 ? {
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
    } : null,

    # Statement 3 (Conditional): This block is only included if the 'service_principals_for_encryption' variable is not empty.
    # It grants specified AWS Services (like EventBridge and Lambda) permission to use the key.
    # This includes 'CreateGrant', which is critical for the Lambda DLQ integration.
    length(var.service_principals_for_encryption) > 0 ? {
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
    } : null
  ]
}

# The KMS Key resource.
resource "aws_kms_key" "this" {
  description             = "KMS key for ${var.key_alias}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = var.tags

  # The policy is constructed from the list of statements in the locals block.
  # The compact() function is essential here, as it removes the 'null' entries that
  # are generated when a conditional statement is false, resulting in a clean and valid JSON policy.
  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = compact(local.policy_statements)
  })
}

# The KMS Alias resource, which gives the key a friendly name.
resource "aws_kms_alias" "this" {
  name          = "alias/${var.key_alias}"
  target_key_id = aws_kms_key.this.key_id
}