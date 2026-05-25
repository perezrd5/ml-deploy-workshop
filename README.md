# NFCU Session 1 — From Model Registry to Production Endpoint

ML deployment pipelines with GitHub Actions and Terraform. Companion repo for the June 2, 2026 NFCU workshop.

## What this repo does

A four-stage pipeline that takes a signed model artifact from S3 to a SageMaker production endpoint with a full audit trail:

1. **Artifact retrieval + validation** — pulls `model.tar.gz` from S3, runs `validate.py` (schema / mutable-reference / policy), verifies cosign signature against `nfcu-model-signing` KMS key
2. **Containerize** — Docker build, Trivy scan (CRITICAL/HIGH = fail), push to ECR, cosign-sign image with `nfcu-image-signing` KMS key
3. **Terraform apply (dev)** — provisions a SageMaker endpoint with private-subnet ENI, KMS-encrypted storage, rolling-update + auto-rollback
4. **Promote to production** — manual `workflow_dispatch` with `change_ticket` input; GitHub `production` environment forces a reviewer; audit event emitted to DynamoDB + S3 on success

## Prerequisites

Before any of this works, the bootstrap stack must be applied to your sandbox account (see `bootstrap-test.sh` in your lab terminal — it provisions VPC, subnets, KMS keys, ECR, S3, DynamoDB, OIDC IdP, IAM roles, and GitHub Environments).

After bootstrap:

1. Run `scripts/build-and-sign-model.sh` once to train + sign + upload the model artifact
2. Set repository variable `AWS_ACCOUNT` (the bootstrap script does this automatically)
3. Edit `terraform/environments/{dev,production}/terraform.tfvars` with bootstrap outputs

## Layout

```
.
├── .github/workflows/
│   ├── deploy-dev.yml          # Auto on push to main
│   └── deploy-production.yml   # Manual; requires approval
├── terraform/
│   ├── modules/sagemaker-endpoint/
│   └── environments/{dev,production}/
├── pipeline/
│   ├── validate.py             # Schema + mutable-ref + policy
│   ├── audit-trail.py          # DynamoDB + S3 audit event
│   └── build-container.sh
├── models/fraud-detector/
│   ├── train.py                # One-time: produces model.pkl
│   ├── inference.py            # SageMaker handler
│   ├── Dockerfile              # Inherits AWS XGBoost base
│   ├── signature.json
│   ├── metadata.json
│   └── model_card.md
├── scripts/
│   └── build-and-sign-model.sh # Train + sign + upload (lab setup)
└── tests/smoke/
    ├── known-input-output.json
    └── sample-payload.json
```

## Demo flow (20 min)

- **A — Repo tour (3 min):** `tree -L 2` + walk through the workflow files
- **B — Trigger dev deploy (4 min):** bump `model_version` in `terraform/environments/dev/terraform.tfvars`, push, watch validate → containerize → terraform-apply go green
- **C — Production with approval gate (4 min):** `gh workflow run deploy-production.yml -f change_ticket=CHG-12345`; approve in the Actions UI
- **D — Five-minute traceability (4 min):** invoke endpoint, then DynamoDB query — returns one row with `commit_sha`, `image_digest`, `training_run_id`, `approver_email`, `deployed_at`
- **E — Fail-closed (3 min):** set `model_version = "latest"` in tfvars, push, watch `validate-artifact` halt with the mutable-ref error
- **F — Rollback wiring (2 min, talk-through):** walk `terraform/modules/sagemaker-endpoint/main.tf` `rolling_update_policy` + `auto_rollback_configuration`

## Key design decisions

A few calls made because the upstream spec and the instructor's lab guide don't agree on every detail — flagged for instructor review if they reach out:

- **Dataset:** the model is XGBoost on UCI Adult Census Income, surfaced as "fraud-detector" per spec naming. Pure stand-in for any production binary classifier. Real fraud features would be a drop-in swap of `signature.json` + `train.py`.
- **Audit storage:** both DynamoDB (per spec) and S3 (per the broader workshop convention). `audit-trail.py` writes to both.
- **Self-approval on production:** the bootstrap currently lets attendees self-approve. For workshop integrity, set `prevent_self_review=true` on the production environment via `gh api` before the demo.
- **SageMaker execution role:** created per-environment by the TF module (not the bootstrap), so dev and prod stay isolated.

## Cleanup

```bash
terraform -chdir=terraform/environments/dev destroy -auto-approve
terraform -chdir=terraform/environments/production destroy -auto-approve
# Then the bootstrap's teardown (see bootstrap-test.sh summary)
```

Save the production endpoint for Session 2 (June 4) — it's the champion variant for the shadow-deployment lab.
