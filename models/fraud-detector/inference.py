"""
SageMaker inference handler for the fraud-detector model.

The four function names below are SageMaker conventions; the framework's
inference container calls them in order:
  model_fn   — load the serialized model from disk (once at boot)
  input_fn   — deserialize the request payload to a DataFrame
  predict_fn — run inference
  output_fn  — serialize the prediction to JSON the caller can read

The model itself is a sklearn Pipeline wrapping a OneHotEncoder + XGBClassifier
so categorical features in signature.json (workclass, education, ...) round-trip
without per-feature plumbing.
"""
import json
import os
import pickle
from typing import Any

import pandas as pd

CONTENT_TYPE_JSON = "application/json"

FEATURE_COLUMNS = [
    "age",
    "workclass",
    "education",
    "marital_status",
    "occupation",
    "race",
    "sex",
    "hours_per_week",
]


def model_fn(model_dir: str) -> Any:
    """Load the pickled sklearn Pipeline. Called once at container start."""
    with open(os.path.join(model_dir, "model.pkl"), "rb") as f:
        return pickle.load(f)


def input_fn(request_body: str, request_content_type: str) -> pd.DataFrame:
    """Accept a single JSON object matching signature.json's input schema, or a
    JSON array of such objects for batch inference."""
    if request_content_type != CONTENT_TYPE_JSON:
        raise ValueError(f"Unsupported content type: {request_content_type}")

    payload = json.loads(request_body)
    if isinstance(payload, dict):
        payload = [payload]
    return pd.DataFrame(payload, columns=FEATURE_COLUMNS)


def predict_fn(input_data: pd.DataFrame, model: Any) -> list:
    """Pipeline handles one-hot encoding internally."""
    probabilities = model.predict_proba(input_data)[:, 1]
    predictions = probabilities >= 0.5
    return [
        {"income_over_50k": bool(p), "probability": float(prob)}
        for p, prob in zip(predictions, probabilities)
    ]


def output_fn(prediction: list, response_content_type: str) -> tuple:
    if response_content_type != CONTENT_TYPE_JSON:
        raise ValueError(f"Unsupported response content type: {response_content_type}")
    # Single-prediction calls get the object directly; batch returns a list.
    body = json.dumps(prediction[0] if len(prediction) == 1 else prediction)
    return body, response_content_type
