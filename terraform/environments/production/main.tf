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
      Environment = "production"
      ManagedBy   = "terraform"
    }
  }
}

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

  environment           = "prod"
  model_version         = var.model_version
  image_uri             = var.image_uri
  image_digest          = var.image_digest
  model_artifact_s3_uri = var.model_artifact_s3_uri
  model_artifact_bucket = var.model_artifact_bucket
  vpc_id                = var.vpc_id
  private_subnet_ids    = var.private_subnet_ids
  kms_key_arn           = var.kms_key_arn

  # Production: bigger instance, two-instance baseline so rolling update has
  # somewhere to drain to.
  instance_type  = "ml.t3.medium"
  instance_count = 2
}

output "endpoint_arn" {
  value = module.sagemaker_endpoint.endpoint_arn
}

output "endpoint_name" {
  value = module.sagemaker_endpoint.endpoint_name
}
