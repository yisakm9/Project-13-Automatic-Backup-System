data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_kms_key" "this" {
  description             = "KMS key for ${var.key_alias}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  tags                    = var.tags

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = concat(
      [
        # Statement 1: Root user access (unchanged)
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
      # Statement 2: For services that ONLY need to encrypt (like EventBridge)
      length(var.service_principals_for_encryption) > 0 ? [
        {
          Sid    = "AllowServicePrincipalsToEncrypt",
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
      # Statement 3: For Lambda service's DLQ integration (needs CreateGrant)
      [
        {
          Sid    = "AllowLambdaServiceToManageDLQ",
          Effect = "Allow",
          Principal = {
            Service = "lambda.amazonaws.com"
          },
          Action   = "kms:CreateGrant",
          Resource = "*",
          Condition = {
             "StringLike" = {
               "kms:GrantIsForAWSResource": "arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:function:*"
            }
          }
        }
      ],
      # Statement 4: For IAM Roles (unchanged)
      length(var.iam_role_arns_for_usage) > 0 ? [
        {
          Sid    = "AllowIAMRolesToUseKey",
          # ... (rest of this statement is correct)
        }
      ] : []
    )
  })
}
resource "aws_kms_alias" "this" {
  name          = "alias/${var.key_alias}"
  target_key_id = aws_kms_key.this.key_id
}