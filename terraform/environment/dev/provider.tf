terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.45.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "2.9.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.9.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }

  # Recommended: remote state in S3. Create the bucket + dynamodb table once,
  # then uncomment. Keeps state out of the local filesystem and supports
  # locking + remote_state reads from other stacks.
  #
  # backend "s3" {
  #   bucket         = "shs-terraform-state"
  #   key            = "environment/dev/terraform.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "terraform-locks"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project
      ManagedBy   = "terraform"
    }
  }
}
