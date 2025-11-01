# Description: Creates a pair of S3 buckets for primary backup and cross-region replication.

# This resource creates a random suffix to ensure bucket names are globally unique.
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# --- IAM Role for S3 Replication ---
# This role grants S3 the permissions needed to replicate objects between buckets.
resource "aws_iam_role" "replication" {
  name = "tf-s3-replication-role-${random_string.suffix.result}"

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

  tags = var.tags
}

resource "aws_iam_policy" "replication" {
  name = "tf-s3-replication-policy-${random_string.suffix.result}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [aws_s3_bucket.primary.arn]
      },
      {
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging"
        ]
        Effect   = "Allow"
        Resource = ["${aws_s3_bucket.primary.arn}/*"]
      },
      {
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags"
        ]
        Effect   = "Allow"
        Resource = ["${aws_s3_bucket.replica.arn}/*"]
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "replication" {
  role       = aws_iam_role.replication.name
  policy_arn = aws_iam_policy.replication.arn
}

# --- Primary S3 Bucket ---
resource "aws_s3_bucket" "primary" {
  bucket = "${var.primary_bucket_prefix}-${random_string.suffix.result}"
  tags   = merge(var.tags, { Name = "${var.primary_bucket_prefix}-primary" })
}

resource "aws_s3_bucket_versioning" "primary_versioning" {
  bucket = aws_s3_bucket.primary.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "primary_encryption" {
  bucket = aws_s3_bucket.primary.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "primary_access_block" {
  bucket                  = aws_s3_bucket.primary.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "primary_lifecycle" {
  bucket = aws_s3_bucket.primary.id
  rule {
    id     = "archive-and-expire-versions"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = var.transition_to_glacier_days
      storage_class   = "GLACIER_IR"
    }

    noncurrent_version_expiration {
      noncurrent_days = var.expire_old_versions_days
    }
  }
}

# --- Replica S3 Bucket ---
# Note: This bucket requires a separate provider configuration for the replica region.
resource "aws_s3_bucket" "replica" {
  provider = aws.replica # Specify the provider for the secondary region
  bucket   = "${var.replica_bucket_prefix}-${random_string.suffix.result}"
  tags     = merge(var.tags, { Name = "${var.replica_bucket_prefix}-replica" })
}

resource "aws_s3_bucket_versioning" "replica_versioning" {
  provider = aws.replica
  bucket   = aws_s3_bucket.replica.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "replica_encryption" {
  provider = aws.replica
  bucket   = aws_s3_bucket.replica.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "replica_access_block" {
  provider                = aws.replica
  bucket                  = aws_s3_bucket.replica.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "replica_lifecycle" {
  provider = aws.replica
  bucket   = aws_s3_bucket.replica.id
  rule {
    id     = "archive-and-expire-versions"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = var.transition_to_glacier_days
      storage_class   = "GLACIER_IR"
    }

    noncurrent_version_expiration {
      noncurrent_days = var.expire_old_versions_days
    }
  }
}

# --- Cross-Region Replication Configuration ---
resource "aws_s3_bucket_replication_configuration" "primary_replication" {
  depends_on = [
    aws_s3_bucket_versioning.replica_versioning
  ]

  role   = aws_iam_role.replication.arn
  bucket = aws_s3_bucket.primary.id

  rule {
    id     = "replicate-all-to-replica"
    status = "Enabled"
    delete_marker_replication {
      status = "Enabled"
    }

    destination {
      bucket        = aws_s3_bucket.replica.arn
      storage_class = "STANDARD"
    }

    filter {} # Empty filter means replicate everything
  }
}