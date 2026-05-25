# Inference container for the fraud-detector model. Inherits the AWS SageMaker
# XGBoost runtime (Python + xgboost + boto3 baked in) and layers the model
# artifact + inference handler on top. Image gets Trivy-scanned in the
# containerize stage; AWS keeps the base image patched but pin to a specific
# minor tag so we get reproducible builds.

FROM 683313688378.dkr.ecr.us-east-1.amazonaws.com/sagemaker-xgboost:1.7-1

# scikit-learn is needed for the Pipeline + OneHotEncoder. The base image
# usually has it, but install explicitly so the build is independent of the
# base's package set.
RUN pip install --no-cache-dir scikit-learn pandas

# SageMaker convention: model artifacts at /opt/ml/model, inference code under
# /opt/ml/model/code/. SAGEMAKER_PROGRAM picks up inference.py from that path.
ENV SAGEMAKER_PROGRAM=inference.py
ENV SAGEMAKER_SUBMIT_DIRECTORY=/opt/ml/model/code

# Copy the trained model + metadata + handler into the container. The
# extracted contents of model.tar.gz (model.pkl, inference.py, metadata.json,
# signature.json, model_card.md) live next to this Dockerfile at build time.
COPY model.pkl /opt/ml/model/model.pkl
COPY metadata.json /opt/ml/model/metadata.json
COPY signature.json /opt/ml/model/signature.json
COPY model_card.md /opt/ml/model/model_card.md
COPY inference.py /opt/ml/model/code/inference.py

# Default port for SageMaker invocation. The base image already exposes it,
# but be explicit.
EXPOSE 8080
