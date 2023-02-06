terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

provider "aws" {
  region                   = "us-east-1"
  shared_config_files      = ["/Users/FOHLEY/.aws/config"]
  shared_credentials_files = ["/Users/FOHLEY/.aws/credentials"]
  profile                  = "terraform_user"
}