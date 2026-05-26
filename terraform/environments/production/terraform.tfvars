aws_region    = "us-east-1"
model_version = "1.0.0"

# image_uri/image_digest get overridden by the containerize job via TF_VAR_*
image_uri             = "REPLACE_ME_FROM_CONTAINERIZE_JOB"
image_digest          = "REPLACE_ME_FROM_CONTAINERIZE_JOB"
model_artifact_s3_uri = "s3://nfcu-s1-models-harshita-kodekloud-1779805653/fraud-detector/model.tar.gz"
model_artifact_bucket = "nfcu-s1-models-harshita-kodekloud-1779805653"
vpc_id                = "vpc-003c588112a356f37"
private_subnet_ids    = ["subnet-0e5100f7980349efe","subnet-0fb62194862f85460"]
kms_key_arn           = "arn:aws:kms:us-east-1:275281117656:key/c22330a8-123d-421b-aa5a-17d410bb5c36"
