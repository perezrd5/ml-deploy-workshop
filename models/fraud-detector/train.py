#!/usr/bin/env python3
"""
One-time training script. Run this once during lab setup to produce
model.pkl. The output is what gets tarred into model.tar.gz, cosign-signed
with the nfcu-model-signing KMS alias, and uploaded to S3 — those steps live
in scripts/build-and-sign-model.sh.

Usage:
    python3 train.py --output models/fraud-detector/model.pkl
"""
import argparse
import pickle
from pathlib import Path

import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder
from xgboost import XGBClassifier

UCI_ADULT_URL = (
    "https://archive.ics.uci.edu/ml/machine-learning-databases/adult/adult.data"
)
COLUMN_NAMES = [
    "age", "workclass", "fnlwgt", "education", "education_num",
    "marital_status", "occupation", "relationship", "race", "sex",
    "capital_gain", "capital_loss", "hours_per_week", "native_country",
    "income",
]

FEATURE_COLUMNS = [
    "age", "workclass", "education", "marital_status",
    "occupation", "race", "sex", "hours_per_week",
]
CATEGORICAL_COLUMNS = [
    "workclass", "education", "marital_status",
    "occupation", "race", "sex",
]


def load_data() -> pd.DataFrame:
    df = pd.read_csv(
        UCI_ADULT_URL,
        names=COLUMN_NAMES,
        sep=", ",
        engine="python",
        na_values="?",
    ).dropna()
    df["target"] = (df["income"] == ">50K").astype(int)
    return df


def build_pipeline() -> Pipeline:
    # Per metadata.json hyperparameters.
    return Pipeline(steps=[
        ("encode", ColumnTransformer(
            transformers=[("cat", OneHotEncoder(handle_unknown="ignore"),
                           CATEGORICAL_COLUMNS)],
            remainder="passthrough",
        )),
        ("xgb", XGBClassifier(
            max_depth=6,
            n_estimators=100,
            learning_rate=0.1,
            objective="binary:logistic",
            eval_metric="logloss",
            random_state=42,
        )),
    ])


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output", default="model.pkl",
        help="Output path for the pickled sklearn Pipeline.",
    )
    args = parser.parse_args()

    print("Loading UCI Adult dataset...")
    df = load_data()

    X = df[FEATURE_COLUMNS]
    y = df["target"]
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y,
    )

    print(f"Training on {len(X_train)} rows...")
    pipeline = build_pipeline()
    pipeline.fit(X_train, y_train)

    acc = pipeline.score(X_test, y_test)
    print(f"Holdout accuracy: {acc:.4f}")

    out = Path(args.output)
    out.parent.mkdir(parents=True, exist_ok=True)
    with open(out, "wb") as f:
        pickle.dump(pipeline, f)
    print(f"Saved pipeline to {out}")


if __name__ == "__main__":
    main()
