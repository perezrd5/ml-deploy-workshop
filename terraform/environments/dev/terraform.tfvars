# Dev environment composition variables.
# model_version is the value validate.py inspects for mutable-reference rejection.
# Demo step E (fail-closed): change this to "latest" and watch the pipeline halt.

aws_region    = "us-east-1"
model_version = "1.0.0"

# These five values are populated per session from the bootstrap stack's
# outputs (/tmp/nfcu-bootstrap-outputs.json). See the pre-req setup steps in
# LAB_GUIDE.md / README.md for the populate-from-bootstrap snippet.
#
# image_uri / image_digest are overridden by the containerize job via TF_VAR_*
# env vars — leave them as REPLACE_ME here.
image_uri             = "REPLACE_ME_FROM_CONTAINERIZE_JOB"
image_digest          = "REPLACE_ME_FROM_CONTAINERIZE_JOB"
model_artifact_s3_uri = "s3://REPLACE_BUCKET/fraud-detector/model.tar.gz"
model_artifact_bucket = "REPLACE_BUCKET"
vpc_id                = "REPLACE_FROM_BOOTSTRAP_OUTPUT"
private_subnet_ids    = ["REPLACE_FROM_BOOTSTRAP_OUTPUT_0", "REPLACE_FROM_BOOTSTRAP_OUTPUT_1"]
kms_key_arn           = "REPLACE_FROM_BOOTSTRAP_OUTPUT"
