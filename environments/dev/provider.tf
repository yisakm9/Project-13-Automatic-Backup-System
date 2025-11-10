# environments/dev/providers.tf

terraform {
  required_version = ">= 1.13.4, < 2.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }

     random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
  
}

provider "aws" {
  region = var.aws_region_primary
}