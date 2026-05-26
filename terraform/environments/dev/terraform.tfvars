aws_region    = "us-east-1"
model_version = "1.0.0"

# image_uri/image_digest get overridden by the containerize job via TF_VAR_*
image_uri             = "REPLACE_ME_FROM_CONTAINERIZE_JOB"
image_digest          = "REPLACE_ME_FROM_CONTAINERIZE_JOB"
model_artifact_s3_uri = "s3://nfcu-s1-models-harshita-kodekloud-1779786332/fraud-detector/model.tar.gz"
model_artifact_bucket = "nfcu-s1-models-harshita-kodekloud-1779786332"
vpc_id                = "vpc-05682e234cd04edb6"
private_subnet_ids    = ["subnet-0175597a98fdf40ae","subnet-0672d1cf777c5ec87"]
kms_key_arn           = "arn:aws:kms:us-east-1:938488749684:key/e8c7a003-bdf8-409b-9d56-890fc0bf88f1"
