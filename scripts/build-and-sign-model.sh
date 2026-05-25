#!/usr/bin/env bash
# One-time-per-version: train the fraud-detector model, package it into the
# expected tarball layout, cosign-sign the tarball with the nfcu-model-signing
# KMS key, and upload both the artifact and its signature to S3.
#
# Run this once during workshop setup. The deploy-dev workflow then pulls the
# signed artifact from S3 and verifies the signature before doing anything.
#
# Usage:
#   AWS_REGION=us-east-1 GH_OWNER=harshita-kodekloud ./scripts/build-and-sign-model.sh

set -euo pipefail

AWS_REGION="${AWS_REGION:-us-east-1}"
GH_OWNER="${GH_OWNER:?Set GH_OWNER to your GitHub username (matches the S3 bucket suffix)}"
S3_BUCKET="${S3_BUCKET:-nfcu-s1-models-${GH_OWNER}}"
S3_KEY_PREFIX="${S3_KEY_PREFIX:-fraud-detector}"
KMS_ALIAS="${KMS_ALIAS:-alias/nfcu-model-signing}"

WORKDIR="$(mktemp -d -t fraud-detector-build-XXXXXX)"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MODEL_DIR="${REPO_ROOT}/models/fraud-detector"

cleanup() { rm -rf "${WORKDIR}"; }
trap cleanup EXIT

echo "==> Train model -> model.pkl"
python3 "${MODEL_DIR}/train.py" --output "${MODEL_DIR}/model.pkl"

echo "==> Compute training_dataset_sha256 and patch metadata.json"
DATASET_SHA=$(curl -fsSL "https://archive.ics.uci.edu/ml/machine-learning-databases/adult/adult.data" \
  | sha256sum | awk '{print $1}')
python3 - <<PY
import json, pathlib
p = pathlib.Path("${MODEL_DIR}/metadata.json")
m = json.loads(p.read_text())
m["training_dataset_sha256"] = "${DATASET_SHA}"
p.write_text(json.dumps(m, indent=2) + "\n")
PY

echo "==> Build tarball"
TARBALL="${WORKDIR}/model.tar.gz"
tar -czf "${TARBALL}" -C "${MODEL_DIR}" \
  model.pkl inference.py signature.json metadata.json model_card.md

echo "==> Cosign sign-blob (KMS-backed model-signing key)"
SIGNATURE="${WORKDIR}/model.sig"
cosign sign-blob \
  --key "awskms:///${KMS_ALIAS#alias/}" \
  --signing-config /tmp/signing-config.json \
  --bundle "${SIGNATURE}.bundle" \
  --output-signature "${SIGNATURE}" \
  --yes \
  "${TARBALL}" || {
    # Fallback: cosign 3.x signing-config dance.
    curl -fsSL https://raw.githubusercontent.com/sigstore/root-signing/refs/heads/main/targets/signing_config.v0.2.json \
      | jq 'del(.rekorTlogUrls)' > /tmp/signing-config.json
    cosign sign-blob \
      --key "awskms:///${KMS_ALIAS#alias/}" \
      --signing-config /tmp/signing-config.json \
      --bundle "${SIGNATURE}.bundle" \
      --yes \
      "${TARBALL}"
}

echo "==> Upload to s3://${S3_BUCKET}/${S3_KEY_PREFIX}/"
aws s3 cp "${TARBALL}"            "s3://${S3_BUCKET}/${S3_KEY_PREFIX}/model.tar.gz"
aws s3 cp "${SIGNATURE}.bundle"   "s3://${S3_BUCKET}/${S3_KEY_PREFIX}/sig"

cat <<EOF

============================================
 Model artifact published
 S3 artifact:  s3://${S3_BUCKET}/${S3_KEY_PREFIX}/model.tar.gz
 S3 signature: s3://${S3_BUCKET}/${S3_KEY_PREFIX}/sig
 Dataset SHA:  ${DATASET_SHA}
============================================

 Verify locally with:
   cosign verify-blob \\
     --key "awskms:///${KMS_ALIAS#alias/}" \\
     --bundle <(aws s3 cp s3://${S3_BUCKET}/${S3_KEY_PREFIX}/sig -) \\
     --insecure-ignore-tlog \\
     <(aws s3 cp s3://${S3_BUCKET}/${S3_KEY_PREFIX}/model.tar.gz -)
EOF
