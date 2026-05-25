#!/usr/bin/env python3
"""
Validation pipeline for fraud-detector model artifacts.
Three checks: schema, mutable-reference, policy. Each fails closed with a
distinct exit code and an attributable error message so on-call can route fast.
"""
import json
import os
import re
import sys
import tarfile
from pathlib import Path

MUTABLE_PATTERNS = re.compile(r"^(latest|prod|current|stable|main)$", re.IGNORECASE)
MIN_MODEL_CARD_BYTES = 100
MIN_ACCURACY = 0.5

EXIT_SCHEMA = 1
EXIT_MUTABLE_REF = 2
EXIT_POLICY = 3


def fail(exit_code: int, msg: str) -> None:
    print(f"VALIDATION FAILED: {msg}", file=sys.stderr)
    sys.exit(exit_code)


def check_schema(artifact_dir: Path) -> None:
    sig_path = artifact_dir / "signature.json"
    if not sig_path.is_file():
        fail(EXIT_SCHEMA, "Schema check — signature.json not found in artifact")
    try:
        sig = json.loads(sig_path.read_text())
    except json.JSONDecodeError as e:
        fail(EXIT_SCHEMA, f"Schema check — signature.json is not valid JSON: {e}")

    for top_key in ("input", "output"):
        if top_key not in sig:
            fail(EXIT_SCHEMA, f"Schema check — missing top-level key '{top_key}'")
        if "type" not in sig[top_key] or "properties" not in sig[top_key]:
            fail(EXIT_SCHEMA, f"Schema check — '{top_key}' missing type/properties")


def check_mutable_reference() -> None:
    # Read from Terraform vars file or env. Lab uses env override; production
    # reads from terraform/environments/<env>/terraform.tfvars.
    model_version = os.environ.get("MODEL_VERSION")
    if not model_version:
        tfvars = os.environ.get("TFVARS_FILE")
        if tfvars and Path(tfvars).is_file():
            for line in Path(tfvars).read_text().splitlines():
                m = re.match(r'\s*model_version\s*=\s*"([^"]+)"', line)
                if m:
                    model_version = m.group(1)
                    break
    if not model_version:
        fail(EXIT_MUTABLE_REF,
             "Mutable artifact reference — model_version is unset; refusing to deploy")

    if MUTABLE_PATTERNS.match(model_version):
        fail(EXIT_MUTABLE_REF,
             f"Mutable artifact reference — '{model_version}' is not allowed; "
             "use immutable semver (e.g. 1.0.0)")


def check_policy(artifact_dir: Path) -> None:
    card = artifact_dir / "model_card.md"
    if not card.is_file():
        fail(EXIT_POLICY, "Policy check — model_card.md missing from artifact")
    if card.stat().st_size < MIN_MODEL_CARD_BYTES:
        fail(EXIT_POLICY,
             f"Policy check — model_card.md is too short "
             f"({card.stat().st_size} bytes, minimum {MIN_MODEL_CARD_BYTES})")

    meta_path = artifact_dir / "metadata.json"
    if not meta_path.is_file():
        fail(EXIT_POLICY, "Policy check — metadata.json missing from artifact")
    try:
        meta = json.loads(meta_path.read_text())
    except json.JSONDecodeError as e:
        fail(EXIT_POLICY, f"Policy check — metadata.json invalid JSON: {e}")

    for required in ("training_run_id", "training_dataset", "evaluation"):
        if required not in meta:
            fail(EXIT_POLICY, f"Policy check — metadata.json missing '{required}'")

    accuracy = meta.get("evaluation", {}).get("accuracy")
    if accuracy is None:
        fail(EXIT_POLICY, "Policy check — metadata.json missing evaluation.accuracy")
    if accuracy < MIN_ACCURACY:
        fail(EXIT_POLICY,
             f"Policy check — evaluation.accuracy {accuracy} below threshold {MIN_ACCURACY}")


def extract_if_tarball(path: Path) -> Path:
    if path.is_dir():
        return path
    if path.suffix in (".gz", ".tgz") or path.name.endswith(".tar.gz"):
        extract_to = Path("/tmp/validate_extract")
        extract_to.mkdir(parents=True, exist_ok=True)
        with tarfile.open(path, "r:gz") as tar:
            tar.extractall(extract_to)
        # Tarball convention: model-vX.Y.Z/ as the root entry.
        children = [p for p in extract_to.iterdir() if p.is_dir()]
        return children[0] if len(children) == 1 else extract_to
    fail(EXIT_SCHEMA, f"Schema check — artifact path {path} is neither dir nor tar.gz")


def main() -> None:
    if len(sys.argv) != 2:
        print("usage: validate.py <artifact-path-or-tarball>", file=sys.stderr)
        sys.exit(EXIT_SCHEMA)

    artifact_dir = extract_if_tarball(Path(sys.argv[1]))

    check_schema(artifact_dir)
    check_mutable_reference()
    check_policy(artifact_dir)

    print("VALIDATION PASSED: schema, reference, policy")
    sys.exit(0)


if __name__ == "__main__":
    main()
