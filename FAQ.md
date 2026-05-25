# FAQ

**Q: Why GitHub Actions and not Jenkins/GitLab/CircleCI?**
Patterns are identical. GitHub Actions has the easiest OIDC federation setup and native Environments for approval gates, which makes it the cleanest demonstration substrate. Translate to your shop's CI of choice.

**Q: Why Terraform and not CDK or Pulumi?**
Same answer. Terraform has the broadest AWS coverage and is most likely already in use. The module pattern translates 1:1 to CDK or Pulumi.

**Q: How does this work for HuggingFace models?**
The artifact format is different (directory of safetensors + config vs. a pickle/joblib bundle) but the four-stage pipeline is identical. Validation gets HuggingFace-specific (model card format, license check); containerization uses a HuggingFace-aware base image; the rest is unchanged.

**Q: What if our model registry is MLflow, not Unity Catalog?**
The artifact retrieval step changes — you call the MLflow REST API instead of S3 directly. Everything downstream is unchanged.

**Q: How do you handle model dependencies that conflict across models?**
Per-model container, never shared base layers between models with conflicting dependencies. The cost is more containers; the benefit is no "library update broke seven models" Saturdays.

**Q: Can I skip the staging environment for low-risk models?**
This repo dropped staging from the original four-environment design — we run dev → production with the production environment's approval gate doing the high-stakes verification. For workloads where staging adds real signal (representative traffic, integration validation), it should be its own composed environment under `terraform/environments/staging/`. The pattern is identical.

**Q: How long does this scale to? 1000 models?**
Linearly. The pipeline is per-model. The Terraform modules are reused. The bottleneck at scale is approval-workflow throughput, not the pipeline itself.

**Q: What's the cost overhead of all this audit machinery?**
DynamoDB on-demand: pennies per month per model. S3 audit JSON: pennies per month per model. Compared to the cost of a single regulatory finding, this is rounding error.

**Q: Does this satisfy SR 11-7?**
SR 11-7 is about model validation governance, not deployment mechanics. This pipeline produces *evidence* that supports SR 11-7 compliance (the audit trail, approval gates, segregation of duties). It does not replace your model validation function.

**Q: When should we NOT use this pattern?**
For models in pure research mode that never see production traffic, the full pipeline is overkill. Use a lighter-weight track for sandbox experiments. Any model touching a real production decision goes through this.

**Q: Why is the "fraud-detector" model trained on UCI Adult Census Income?**
Pragmatic stand-in. The pipeline is the lesson, not the model. Real fraud features (transaction amount, merchant category, time-of-day deltas) are a drop-in swap of `signature.json`, `train.py`, and the categorical mappings in `inference.py`.

**Q: Why does production validate the artifact a second time?**
Belt-and-braces. The same artifact ran through validate-artifact in dev; running it again at production promotion catches any tampering between the dev deploy and the promotion event. Cosign verify is cheap; an undetected swap is not.

**Q: The KMS aliases (`nfcu-model-signing`, `nfcu-image-signing`) — one key or two?**
Two keys, each asymmetric (ECC_NIST_P256, SIGN_VERIFY). Separating model signing from image signing means each can be rotated independently and granted to different roles. The bootstrap script also creates a third symmetric key (`encryption`) for SSE-KMS on S3/DynamoDB/ECR — that one's distinct.

**Q: Why does Trivy run with `--ignore-unfixed`?**
Because a CRITICAL CVE with no available fix is operationally meaningful but blocking-wise useless — you can't act on it. The workshop uses `--ignore-unfixed` to avoid spurious failures from base-image CVEs with no upstream patch yet. In production, periodically re-scan without `--ignore-unfixed` and triage what comes back via a documented allowlist with expiration dates.

**Q: What if the production endpoint fails post-deploy?**
The `aws_cloudwatch_metric_alarm.endpoint_5xx` alarm (created by the SageMaker module) is wired into `auto_rollback_configuration`. During a rolling update, if 5xx errors cross threshold, SageMaker rolls back to the previous variant automatically. The workshop names this but doesn't break a prod endpoint to exercise it.
