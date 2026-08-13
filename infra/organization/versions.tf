terraform {
  required_version = ">= 1.15.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0, < 7.0"
    }
  }

  backend "s3" {}
}

provider "aws" {
  region              = "us-east-2"
  allowed_account_ids = ["699599381258"]
}
