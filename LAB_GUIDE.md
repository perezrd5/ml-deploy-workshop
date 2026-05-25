# Lab Guide — Session 1

Step-by-step for attendees. The session has four labs interleaved with speaker blocks. Each lab has clear success criteria; if you fall behind, post in the workshop Slack and a lab assistant will pair with you.

---

## Pre-flight (off the clock)

Before Lab 1 starts:

```bash
# Verify lab shell access
aws sts get-caller-identity
gh auth status

# Pull your fork
cd ~ && git clone https://github.com/<your-gh>/nfcu-s1-demo.git
cd nfcu-s1-demo
```

The instructor will confirm everyone's bootstrap stack is in place before starting.

---

## Lab 1 — Run the Validation Pipeline (12 min)

You'll watch validation pass on a clean push, then break it deliberately to see fail-closed behavior.

**Step 1 — Run validation on a clean artifact (4 min)**

1. Open `.github/workflows/deploy-dev.yml` in your IDE; locate the `validate-artifact` job
2. Make a trivial change to `README.md` (add a comment line)
3. ```git commit -am "trigger validation" && git push```
4. Open the Actions tab and watch validation run; confirm green

**Step 2 — Break it deliberately (5 min)**

5. Edit `terraform/environments/dev/terraform.tfvars`
6. Change `model_version = "1.0.0"` to `model_version = "latest"`
7. Commit and push
8. Watch validation fail in the Actions tab
9. Read the failure log — should say "Mutable artifact reference — 'latest' is not allowed; use immutable semver". That's Check 2 in `pipeline/validate.py`
10. Revert: change `model_version` back to `"1.0.0"`; push; verify green

**Success criterion:** both a green and a red validation run visible in the Actions tab.

---

## Lab 2 — Run the Full Container Stage (12 min)

Lab 1 deliberately skipped the containerize job (workflow ran validate only). Now you enable it and see the full pipeline.

11. The container stage is gated on whether the artifact has been signed and uploaded. Confirm it has:
   ```bash
   aws s3 ls s3://nfcu-s1-models-$(gh api user --jq .login)/fraud-detector/
   ```
   You should see `model.tar.gz` and `sig`.
12. Push any small change to trigger the workflow again (or use `gh workflow run deploy-dev.yml`)
13. Watch the full pipeline: validate-artifact → containerize → terraform-apply-dev (~5 min total)
14. In ECR Console, navigate to the `fraud-detector` repository
15. Confirm: an image tagged with your commit SHA, AND a cosign signature artifact (`.sig` suffix)
16. Compare the digest from the workflow log against the digest shown in ECR — they should match
17. ```aws ecr describe-images --repository-name fraud-detector --image-ids imageTag=$(git rev-parse HEAD) --query 'imageDetails[0].imageDigest'```

**Success criterion:** image + signature visible in ECR with matching digest.

---

## Lab 3 — Deploy to Dev (15 min — your big checkpoint)

The dev endpoint provisions during this lab. Endpoint creation takes 4–6 min.

18. Open `terraform/modules/sagemaker-endpoint/main.tf` — read through the resources. Note:
    - Private-subnet ENI (no public IP)
    - KMS encryption on endpoint storage
    - Execution role pass-through
    - The `rolling_update_policy` + `auto_rollback_configuration` blocks — this is where rollback lives (named in Demo F, not exercised in lab time)
19. The workflow already kicked off `terraform-apply-dev` in Lab 2. Open the run; the apply step is in progress.
20. While provisioning, read `terraform/modules/sagemaker-endpoint/variables.tf` to understand the module interface.
21. When apply completes: ```aws sagemaker describe-endpoint --endpoint-name fraud-detector-dev --query EndpointStatus```
    Should be `InService`.
22. Invoke it:
    ```bash
    aws sagemaker-runtime invoke-endpoint \
      --endpoint-name fraud-detector-dev \
      --content-type application/json \
      --body file://tests/smoke/sample-payload.json \
      /tmp/response.json
    cat /tmp/response.json
    ```
23. Should return `{"income_over_50k": false, "probability": 0.18}` (or similar).

**Success criterion:** endpoint `InService`, sample prediction returns a JSON object with both fields.

---

## Lab 4 — Promote with Approval (15 min)

24. From the GitHub Actions tab, click "Run workflow" on `deploy-production.yml`
25. Fill in `change_ticket`: `CHG-12345`
26. Workflow runs validate-artifact → resolve-image → terraform-apply-production
27. At `terraform-apply-production`, the workflow **pauses** — the production environment has a required reviewer
28. Open the run; you'll see "Waiting for review"
29. Approve via the UI (or `gh run approve <run-id>` — see the note below about self-approval)
30. Production deploy completes; rolling update brings up the prod endpoint
31. Verify the audit trail:
    ```bash
    aws dynamodb query --table-name model-deployment-audit \
      --key-condition-expression "endpoint_name = :e" \
      --expression-attribute-values '{":e":{"S":"fraud-detector-prod"}}' \
      --max-items 1
    ```
32. The returned row contains: `commit_sha`, `image_digest`, `training_run_id`, `approver_email`, `deployed_at`, `change_ticket_reference`. **That's the chain. That's the five-minute answer.**

**Success criterion:** prod endpoint live + audit row with all six fields present.

> **Note on self-approval:** by default the bootstrap allows you to approve your own production deployment. In real environments that defeats the security control — `prevent_self_review=true` should be enabled on the production environment, and a separate reviewer (buddy or instructor service account) used. For lab purposes, self-approval is the path of least resistance.

---

## Cleanup

The lab platform auto-tears-down endpoints at session end + 30 minutes. Save your repo — Session 2 (June 4) picks up from Lab 4's production endpoint.
