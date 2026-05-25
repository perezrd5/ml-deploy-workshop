# fraud-detector Model Card

## Overview
**Model name:** fraud-detector
**Version:** 1.0.0
**Type:** Binary classifier
**Framework:** XGBoost (via scikit-learn Pipeline + OneHotEncoder)

## Intended Use
This is a workshop training artifact. It demonstrates the deployment pipeline
mechanics (validate → containerize → deploy → audit) that any production
binary classifier at NFCU would flow through. The model itself is a stand-in,
not a credit-decisioning model.

## Training Data
**Dataset:** UCI Adult Census Income (public, CC BY 4.0)
**Snapshot:** uci-adult-2024-snapshot
**Target:** Income > $50K

UCI Adult is used because it is the canonical small ML example for binary
classification — the deployment pipeline is the lesson, not the model quality.
Production credit-decisioning models would never include the `race` or `sex`
features that appear in the input schema; fair-lending regulations restrict
their use.

## Performance
- Accuracy: 0.86 (holdout)
- F1 score: 0.71

## Limitations
- Trained on 1994 Census data — not representative of 2026 populations.
- No fairness audit. Do not use for any real decisioning workflow.
- Categorical encoding is one-hot inside the Pipeline; unseen categories at
  inference time return zeros for that column.

## Lineage
- Training run ID: lab-train-2026-05-15-abc123 (placeholder; produced by train.py)
- Container base: AWS SageMaker XGBoost 1.7-1 inference image
- Pipeline: sklearn ColumnTransformer(OneHotEncoder) → XGBClassifier

## Contact
NFCU Workshop Team. Replace this section with the real model owner before any
non-workshop use.
