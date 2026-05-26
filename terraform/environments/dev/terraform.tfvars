aws_region    = "us-east-1"
model_version = "1.0.0"

# image_uri/image_digest get overridden by the containerize job via TF_VAR_*
image_uri             = "REPLACE_ME_FROM_CONTAINERIZE_JOB"
image_digest          = "REPLACE_ME_FROM_CONTAINERIZE_JOB"
model_artifact_s3_uri = "s3://nfcu-s1-models-harshita-kodekloud-t4/fraud-detector/model.tar.gz"
model_artifact_bucket = "nfcu-s1-models-harshita-kodekloud-t4"
vpc_id                = "vpc-03398ac09d08fc37a"
private_subnet_ids    = ["subnet-092969d068495f65b","subnet-09de9b3119e0481d5"]
kms_key_arn           = "arn:aws:kms:us-east-1:223825748658:key/dc3374d8-ed3d-4b96-81c9-715eb91cccbc"
