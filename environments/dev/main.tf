# Description: Root module for the 'dev' environment.
# This file composes the reusable modules to build the complete infrastructure.

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# Provider for the primary region
provider "aws" {
  region = var.aws_region_primary
  alias  = "primary"
}

# Provider for the replica region
provider "aws" {
  region = var.aws_region_replica
  alias  = "replica"
}

# --- S3 Backup Buckets Module ---
module "s3_backup_buckets" {
  source = "../../modules/s3_backup_buckets"

  # We pass the replica provider to the module so it can create resources in the second region
  providers = {
    aws.replica = aws.replica
  }

  primary_bucket_prefix = "${var.project_name}-primary-${var.environment}"
  replica_bucket_prefix = "${var.project_name}-replica-${var.environment}"
  aws_region_replica    = var.aws_region_replica

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}