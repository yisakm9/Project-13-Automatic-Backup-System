# ADD THIS ENTIRE BLOCK AT THE TOP OF THE FILE
terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      # This configuration declares that the module can accept a provider with the 'replica' alias
      configuration_aliases = [aws.replica]
    }
  }
}