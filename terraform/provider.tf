terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote backend with state locking.
  # S3 stores the state file; DynamoDB provides the lock so two people/pipelines
  # can never apply at the same time and corrupt state.
  backend "s3" {
    bucket         = "test-assessment-tfstate"     # pre-created, versioned S3 bucket
    key            = "eks/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "test-assessment-tf-locks"    # pre-created DynamoDB table, key = LockID
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
}
