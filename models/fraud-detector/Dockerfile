# Inference container for the fraud-detector model. Inherits the AWS SageMaker
# XGBoost runtime (Python + xgboost + boto3 baked in) and layers the model
# artifact + inference handler on top. Image gets Trivy-scanned in the
# containerize stage; AWS keeps the base image patched but pin to a specific
# minor tag so we get reproducible builds.

FROM 683313688378.dkr.ecr.us-east-1.amazonaws.com/sagemaker-xgboost:1.7-1

# scikit-learn is needed for the Pipeline + OneHotEncoder. Pin numpy < 2 and
# sklearn 1.5.2 so the inference env matches the training env — pickles made
# with numpy 2.x reference numpy._core.multiarray which doesn't exist in
# numpy 1.x and the AWS XGBoost 1.7-1 base image is numpy 1.x.
RUN pip install --no-cache-dir "numpy<2" "scikit-learn==1.5.2" pandas xgboost==1.7.4

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
