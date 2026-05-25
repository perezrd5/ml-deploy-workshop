# Production environment composition variables.
# model_version drives validate.py's mutable-reference check. Promotion to prod
# requires bumping this value in a PR and getting it through the production
# environment's required-reviewer gate.

aws_region    = "us-east-1"
model_version = "1.0.0"

image_uri             = "REPLACE_ME_FROM_CONTAINERIZE_JOB"
image_digest          = "REPLACE_ME_FROM_CONTAINERIZE_JOB"
model_artifact_s3_uri = "s3://REPLACE_BUCKET/fraud-detector/model.tar.gz"
model_artifact_bucket = "REPLACE_BUCKET"
vpc_id                = "REPLACE_FROM_BOOTSTRAP_OUTPUT"
private_subnet_ids    = ["REPLACE_FROM_BOOTSTRAP_OUTPUT_0", "REPLACE_FROM_BOOTSTRAP_OUTPUT_1"]
kms_key_arn           = "REPLACE_FROM_BOOTSTRAP_OUTPUT"
