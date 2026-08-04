terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Exemplo: criar um bucket S3
resource "aws_s3_bucket" "meu_bucket" {
  bucket = "meu-bucket-terraform-teste-12345"
}