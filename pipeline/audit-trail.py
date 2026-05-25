#!/usr/bin/env python3
"""
Emit a structured audit event to DynamoDB (model-deployment-audit table) AND
mirror to S3 (audit JSON, Athena-queryable). Run as the final step of every
successful production deploy. Fields match the spec's traceability schema so
the five-minute audit query returns the full chain in one shot.
"""
import argparse
import json
import os
import sys
from datetime import datetime, timezone

import boto3


def load_metadata(metadata_path: str) -> dict:
    with open(metadata_path) as f:
        return json.load(f)


def build_event(env: str, metadata: dict) -> dict:
    now = datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")
    endpoint_name = f"fraud-detector-{env}"
    return {
        "endpoint_name": endpoint_name,
        "deployed_at": now,
        "event": "production_deploy_completed" if env == "prod" else f"{env}_deploy_completed",
        "endpoint_arn": os.environ.get("ENDPOINT_ARN", ""),
        "endpoint_version": metadata.get("model_version", ""),
        "container_digest": os.environ.get("IMAGE_DIGEST", ""),
        "artifact_version": metadata.get("model_version", ""),
        "artifact_s3_uri": os.environ.get("ARTIFACT_S3_URI", ""),
        "training_run_id": metadata.get("training_run_id", ""),
        "training_dataset": metadata.get("training_dataset", ""),
        "commit_sha": os.environ.get("GITHUB_SHA", ""),
        "git_repo": os.environ.get("GITHUB_REPOSITORY", ""),
        "approver_email": os.environ.get("APPROVER_EMAIL", os.environ.get("GITHUB_ACTOR", "")),
        "change_ticket_reference": os.environ.get("CHANGE_TICKET_REFERENCE", ""),
        "deployment_workflow_run_url": (
            f"{os.environ.get('GITHUB_SERVER_URL', 'https://github.com')}/"
            f"{os.environ.get('GITHUB_REPOSITORY', '')}/actions/runs/"
            f"{os.environ.get('GITHUB_RUN_ID', '')}"
        ),
    }


def write_to_dynamodb(table_name: str, event: dict) -> None:
    ddb = boto3.client("dynamodb")
    item = {k: {"S": str(v)} for k, v in event.items() if v != ""}
    ddb.put_item(TableName=table_name, Item=item)


def write_to_s3(bucket: str, event: dict) -> str:
    # Key path: audit/{date}/{commit_sha}.json — partitioned by date for Athena.
    date = event["deployed_at"][:10]
    sha = event.get("commit_sha") or "no-sha"
    key = f"audit/{date}/{sha}.json"
    s3 = boto3.client("s3")
    s3.put_object(
        Bucket=bucket,
        Key=key,
        Body=json.dumps(event, indent=2).encode(),
        ContentType="application/json",
        ServerSideEncryption="aws:kms",
    )
    return f"s3://{bucket}/{key}"


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--env", required=True, choices=["dev", "prod"],
                   help="Target environment (dev or prod)")
    p.add_argument("--metadata", default="models/fraud-detector/metadata.json",
                   help="Path to model metadata.json")
    p.add_argument("--ddb-table", default="model-deployment-audit",
                   help="DynamoDB audit table name")
    p.add_argument("--s3-bucket", default=None,
                   help="Audit S3 bucket (default: $AUDIT_BUCKET env var)")
    args = p.parse_args()

    bucket = args.s3_bucket or os.environ.get("AUDIT_BUCKET")
    if not bucket:
        print("audit-trail: AUDIT_BUCKET or --s3-bucket required", file=sys.stderr)
        sys.exit(1)

    metadata = load_metadata(args.metadata)
    event = build_event(args.env, metadata)

    write_to_dynamodb(args.ddb_table, event)
    s3_uri = write_to_s3(bucket, event)

    print(f"Audit event emitted: endpoint={event['endpoint_name']} "
          f"commit={event['commit_sha']} ddb={args.ddb_table} s3={s3_uri}")


if __name__ == "__main__":
    main()
