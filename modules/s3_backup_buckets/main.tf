# Description: Main configuration for the s3_backup_buckets module.
# This module creates a primary and a replica S3 bucket with versioning,
# encryption, public access blocked, lifecycle policies, and cross-region replication.

provider "aws" {
  alias  = "replica"
  region = var.aws_region_replica
}

resource "aws_s3_bucket" "primary" {
  bucket = var.primary_bucket_name
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "primary" {
  bucket = aws_s3_bucket.primary.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "primary" {
  bucket = aws_s3_bucket.primary.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "primary" {
  bucket                  = aws_s3_bucket.primary.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "replica" {
  provider = aws.replica
  bucket   = var.replica_bucket_name
  tags     = var.tags
}

resource "aws_s3_bucket_versioning" "replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.replica.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.replica.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "replica" {
  provider                = aws.replica
  bucket                  = aws_s3_bucket.replica.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_role" "replication" {
  name = "s3-crr-role-${var.primary_bucket_name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy" "replication" {
  name = "s3-crr-policy-${var.primary_bucket_name}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:ListBucket",
          "s3:GetObjectVersion",
          "s3:GetObjectVersionAcl"
        ]
        Effect   = "Allow"
        Resource = [
          aws_s3_bucket.primary.arn,
          "${aws_s3_bucket.primary.arn}/*",
        ]
      },
      {
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.replica.arn}/*"
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "replication" {
  role       = aws_iam_role.replication.name
  policy_arn = aws_iam_policy.replication.arn
}

resource "aws_s3_bucket_replication_configuration" "primary" {
  depends_on = [aws_s3_bucket_versioning.primary, aws_s3_bucket_versioning.replica]
  role       = aws_iam_role.replication.arn
  bucket     = aws_s3_bucket.primary.id

  rule {
    id       = "primary-to-replica"
    priority = 1
    status   = "Enabled"

    # The delete_marker_replication block has been removed to align with the V2 schema.
    # Delete marker replication is now enabled by default when versioning is active on both buckets.

    destination {
      bucket = aws_s3_bucket.replica.arn
      # The storage_class attribute is not needed here in the V2 schema for standard replication.
    }

    # By default, everything is replicated. To be explicit:
    filter {}
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "primary" {
  bucket = aws_s3_bucket.primary.id
  rule {
    id     = "backup-lifecycle-rule"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = var.transition_to_glacier_ir_days
      storage_class   = "GLACIER_IR"
    }
    noncurrent_version_expiration {
      noncurrent_days = var.expiration_days
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.replica.id
  rule {
    id     = "backup-lifecycle-rule"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = var.transition_to_glacier_ir_days
      storage_class   = "GLACIER_IR"
    }
    noncurrent_version_expiration {
      noncurrent_days = var.expiration_days
    }
  }
}