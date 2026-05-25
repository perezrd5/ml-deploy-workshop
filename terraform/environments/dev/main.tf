terraform {
  required_version = ">= 1.14"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "nfcu-s1-demo"
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}

# All five values below are bootstrap outputs. In a real org you'd pull them
# from remote state; here they're passed via terraform.tfvars to keep the lab
# legible.
variable "aws_region"            { type = string }
variable "model_version"         { type = string }
variable "image_uri"              { type = string }
variable "image_digest"           { type = string }
variable "model_artifact_s3_uri"  { type = string }
variable "model_artifact_bucket"  { type = string }
variable "vpc_id"                 { type = string }
variable "private_subnet_ids"     { type = list(string) }
variable "kms_key_arn"            { type = string }

module "sagemaker_endpoint" {
  source = "../../modules/sagemaker-endpoint"

  environment           = "dev"
  model_version         = var.model_version
  image_uri             = var.image_uri
  image_digest          = var.image_digest
  model_artifact_s3_uri = var.model_artifact_s3_uri
  model_artifact_bucket = var.model_artifact_bucket
  vpc_id                = var.vpc_id
  private_subnet_ids    = var.private_subnet_ids
  kms_key_arn           = var.kms_key_arn

  instance_type  = "ml.t3.medium"
  instance_count = 1
}

output "endpoint_arn" {
  value = module.sagemaker_endpoint.endpoint_arn
}

output "endpoint_name" {
  value = module.sagemaker_endpoint.endpoint_name
}
