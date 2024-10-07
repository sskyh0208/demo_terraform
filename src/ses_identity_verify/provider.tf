terraform {
  required_version = ">= 1.8.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.68.0"
    }
  }
}

provider "aws" {
  shared_config_files      = ["/root/.aws/config"]
  shared_credentials_files = ["/root/.aws/credentials"]
  profile                  = local.env_name

  default_tags {
    tags = {
      Product = var.product_name
      Env     = local.env_name
    }
  }
}

provider "aws" {
  alias  = "virginia"
  region = "us-east-1"

  shared_config_files      = ["/root/.aws/config"]
  shared_credentials_files = ["/root/.aws/credentials"]
  profile                  = local.env_name

  default_tags {
    tags = {
      Product = var.product_name
      Env     = local.env_name
    }
  }
}