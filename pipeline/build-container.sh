#!/usr/bin/env bash
# Lab-side container build helper. The workflow does this inline as separate
# steps for clarity; this script collapses the same flow into a single command
# for local iteration.
#
# Prereqs: docker, aws CLI, cosign, trivy on PATH; AWS creds set; the model
# artifact extracted into models/fraud-detector/ (model.pkl + metadata.json
# + signature.json + model_card.md + inference.py).

set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
ECR_REPOSITORY="${ECR_REPOSITORY:-fraud-detector}"
IMAGE_TAG="${IMAGE_TAG:-$(git rev-parse HEAD 2>/dev/null || echo manual-$(date +%s))}"
KMS_ALIAS="${KMS_ALIAS:-alias/nfcu-image-signing}"

AWS_ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
REGISTRY="${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com"
IMAGE_URI="${REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}"

echo "==> Building ${IMAGE_URI}"
docker build -t "fraud-detector:${IMAGE_TAG}" models/fraud-detector/

echo "==> Trivy scan (CRITICAL/HIGH must be zero)"
trivy image \
  --severity CRITICAL,HIGH \
  --exit-code 1 \
  --ignore-unfixed \
  "fraud-detector:${IMAGE_TAG}"

echo "==> ECR login"
aws ecr get-login-password --region "${AWS_REGION}" \
  | docker login --username AWS --password-stdin "${REGISTRY}"

echo "==> Tag + push"
docker tag "fraud-detector:${IMAGE_TAG}" "${IMAGE_URI}"
docker push "${IMAGE_URI}"

IMAGE_DIGEST=$(aws ecr describe-images \
  --repository-name "${ECR_REPOSITORY}" \
  --image-ids imageTag="${IMAGE_TAG}" \
  --query 'imageDetails[0].imageDigest' --output text)

echo "==> Cosign sign (KMS-backed) — references by digest, not tag"
cosign sign \
  --key "awskms:///${KMS_ALIAS#alias/}" \
  --tlog-upload=false \
  --use-signing-config=false \
  --yes \
  "${REGISTRY}/${ECR_REPOSITORY}@${IMAGE_DIGEST}"

cat <<EOF

============================================
 Container build complete
 Image URI:    ${IMAGE_URI}
 Image digest: ${IMAGE_DIGEST}
============================================
EOF
