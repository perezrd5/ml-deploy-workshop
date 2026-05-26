variable "environment" {
  description = "Deployment environment — drives endpoint name (fraud-detector-{env}) and isolates IAM roles per env."
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be 'dev' or 'prod' (staging is dropped in this spec)."
  }
}

variable "model_version" {
  description = "Immutable semver model version (e.g. 1.0.0). validate.py rejects mutable refs like 'latest'."
  type        = string
}

variable "image_uri" {
  description = "ECR image URI tagged with the commit SHA. Comes from the containerize job's output."
  type        = string
}

variable "image_digest" {
  description = "SHA256 digest of the ECR image — the immutable handle that should be in the audit trail, not the tag."
  type        = string
}

variable "model_artifact_s3_uri" {
  description = "S3 URI of the signed model.tar.gz (the validate-artifact stage already verified the cosign signature)."
  type        = string
}

variable "model_artifact_bucket" {
  description = "S3 bucket containing the model artifact — used to scope the execution role's s3:GetObject permission."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID from the bootstrap stack. Endpoints run in private subnets only."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets (>=2 AZs) from the bootstrap stack."
  type        = list(string)
}

variable "kms_key_arn" {
  description = "Bootstrap encryption KMS key — used for endpoint storage encryption and granted to the exec role for Decrypt."
  type        = string
}

variable "instance_type" {
  description = "SageMaker instance type. ml.m5.large for lab (in the AWS provider's hardcoded allowlist); ml.m5.xlarge realistic for production fraud inference."
  type        = string
  default     = "ml.m5.large"
}

variable "instance_count" {
  description = "Initial instance count for the production variant. 1 for dev; 2+ for production HA."
  type        = number
  default     = 1
}
