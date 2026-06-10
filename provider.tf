# AWS Provider
provider "aws" {
  region  = var.region
  profile = "default"
}

# Terraform backend — S3 state storage
terraform {
  backend "s3" {
    bucket  = "pet-adoption-state-bucket-two2"
    key     = "vault-jenkins/terraform.tfstate"
    region  = "eu-west-3"
    encrypt = true
    profile = "default"
  }
}
