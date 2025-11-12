data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_kms_key" "this" {
  description             = "KMS key for ${var.key_alias}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = var.tags

  # CORRECTED: Use dynamic blocks to generate policy statements conditionally
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = concat(
      [
        # Statement 1: Always allow the root user to manage the key
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
      # Statement 2: Only add this block if the service_principals_for_encryption list is not empty
      length(var.service_principals_for_encryption) > 0 ? [
        {
          Sid    = "AllowServicePrincipalsToUseKey",
          Effect = "Allow",
          Principal = {
            Service = var.service_principals_for_encryption
          },
          Action = [
            "kms:GenerateDataKey",
            "kms:Decrypt"
          ],
          Resource = "*"
        }
      ] : [],
      # Statement 3: Only add this block if the iam_role_arns_for_usage list is not empty
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
      ] : []
    )
  })
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.key_alias}"
  target_key_id = aws_kms_key.this.key_id
}