data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_kms_key" "this" {
  description             = "KMS key for ${var.key_alias}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = var.tags

  # Define the key policy
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      # Statement 1: Allows the root user of the account to manage the key
      {
        Sid    = "EnableIAMUserPermissions",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      },
      # Statement 2: CRITICAL - Allows specified AWS services (like EventBridge) to use the key
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
        Resource = "*" # Resource must be "*" for key usage permissions
      }
    ]
  })
}

resource "aws_kms_alias" "this" {
  name          = "alias/${var.key_alias}"
  target_key_id = aws_kms_key.this.key_id
}