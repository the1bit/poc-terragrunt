# Root Terragrunt config - uses environment variables for AWS provider
# Set AWS_PROFILE and (optionally) AWS_REGION before running terragrunt.

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terraform"
  contents  = <<-EOF
    terraform {
      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = "~> 5.0"
        }
      }
    }

    provider "aws" {
      profile = "${get_env("AWS_PROFILE", "default")}"
      region  = "${get_env("AWS_REGION", "eu-central-1")}"
    }
  EOF
}
