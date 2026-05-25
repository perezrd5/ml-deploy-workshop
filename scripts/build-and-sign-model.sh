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
GH_OWNER="${GH_OWNER:?Set GH_OWNER to your GitHub username}"
GH_REPO="${GH_REPO:-nfcu-s1-demo}"

# Prefer the MODEL_BUCKET repo variable set by the bootstrap; fall back to an
# explicit S3_BUCKET env override; error out if neither is available so we
# never sign+upload to the wrong bucket by accident.
if [ -z "${S3_BUCKET:-}" ] && command -v gh >/dev/null 2>&1; then
  S3_BUCKET=$(gh variable get MODEL_BUCKET --repo "${GH_OWNER}/${GH_REPO}" 2>/dev/null || true)
fi
S3_BUCKET="${S3_BUCKET:?S3_BUCKET unset and gh variable MODEL_BUCKET not found on ${GH_OWNER}/${GH_REPO}. Set one or the other.}"

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
SIGNATURE="${WORKDIR}/model.bundle"

# Cosign 3.x requires a signing-config to opt out of the transparency log.
# Create one with rekor stripped before signing.
curl -fsSL https://raw.githubusercontent.com/sigstore/root-signing/refs/heads/main/targets/signing_config.v0.2.json \
  | jq 'del(.rekorTlogUrls)' > /tmp/signing-config.json

# KMS_ALIAS keeps its `alias/` prefix in the cosign URL (awskms:///alias/<name>).
cosign sign-blob \
  --key "awskms:///${KMS_ALIAS}" \
  --signing-config /tmp/signing-config.json \
  --bundle "${SIGNATURE}" \
  --yes \
  "${TARBALL}"

echo "==> Upload to s3://${S3_BUCKET}/${S3_KEY_PREFIX}/"
aws s3 cp "${TARBALL}"   "s3://${S3_BUCKET}/${S3_KEY_PREFIX}/model.tar.gz"
aws s3 cp "${SIGNATURE}" "s3://${S3_BUCKET}/${S3_KEY_PREFIX}/sig"

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
