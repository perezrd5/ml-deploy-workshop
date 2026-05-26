terraform {
  required_version = ">= 1.14"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }
}

locals {
  endpoint_name = "fraud-detector-${var.environment}"
  model_name    = "fraud-detector-${var.environment}-${replace(var.model_version, ".", "-")}"
}

# --- SageMaker execution role -----------------------------------------------
# The endpoint runtime assumes this role to fetch the model artifact from S3,
# pull the container from ECR, and write logs. Least-privilege at lab scope.
resource "aws_iam_role" "execution" {
  name = "nfcu-s1-sagemaker-exec-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sagemaker.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "execution" {
  role = aws_iam_role.execution.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.model_artifact_bucket}",
          "arn:aws:s3:::${var.model_artifact_bucket}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey"
        ]
        Resource = var.kms_key_arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:CreateNetworkInterfacePermission",
          "ec2:DeleteNetworkInterface",
          "ec2:DeleteNetworkInterfacePermission",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeVpcs",
          "ec2:DescribeDhcpOptions",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

# --- Security group for the endpoint ENIs -----------------------------------
resource "aws_security_group" "endpoint" {
  name        = "nfcu-s1-sagemaker-${var.environment}"
  description = "SageMaker endpoint ENIs - egress only, no ingress (ASCII only per AWS EC2 requirement)"
  vpc_id      = var.vpc_id

  # Egress to ECR (via VPC endpoint) and S3 (via gateway endpoint).
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- SageMaker model --------------------------------------------------------
resource "aws_sagemaker_model" "this" {
  name               = local.model_name
  execution_role_arn = aws_iam_role.execution.arn

  primary_container {
    image          = var.image_uri
    model_data_url = var.model_artifact_s3_uri
    environment = {
      SAGEMAKER_PROGRAM          = "inference.py"
      SAGEMAKER_SUBMIT_DIRECTORY = "/opt/ml/model/code"
    }
  }

  vpc_config {
    subnets            = var.private_subnet_ids
    security_group_ids = [aws_security_group.endpoint.id]
  }
}

# --- Endpoint configuration -------------------------------------------------
resource "aws_sagemaker_endpoint_configuration" "this" {
  name = "${local.endpoint_name}-cfg-${replace(var.model_version, ".", "-")}"

  production_variants {
    variant_name           = "primary"
    model_name             = aws_sagemaker_model.this.name
    initial_instance_count = var.instance_count
    instance_type          = var.instance_type
    initial_variant_weight = 1
  }

  kms_key_arn = var.kms_key_arn
}

# --- The endpoint itself, with rolling-update + auto-rollback ---------------
# The rolling-update + auto_rollback wiring is the rollback mechanism the
# workshop names but deliberately does not break in lab time.
resource "aws_sagemaker_endpoint" "this" {
  name                 = local.endpoint_name
  endpoint_config_name = aws_sagemaker_endpoint_configuration.this.name

  # SageMaker rejects rolling-update batches >50% of desired capacity, so the
  # policy is only meaningful with 2+ instances. Dev runs a single instance to
  # keep cost down and skips the block entirely.
  dynamic "deployment_config" {
    for_each = var.instance_count >= 2 ? [1] : []
    content {
      rolling_update_policy {
        maximum_batch_size {
          type  = "INSTANCE_COUNT"
          value = 1
        }
        wait_interval_in_seconds             = 60
        maximum_execution_timeout_in_seconds = 3600
      }
      auto_rollback_configuration {
        alarms {
          alarm_name = aws_cloudwatch_metric_alarm.endpoint_5xx.alarm_name
        }
      }
    }
  }
}

# --- CloudWatch alarm referenced by auto_rollback ---------------------------
resource "aws_cloudwatch_metric_alarm" "endpoint_5xx" {
  alarm_name          = "${local.endpoint_name}-5xx"
  alarm_description   = "Triggers SageMaker auto-rollback when 5xx errors spike during a rolling update"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Invocation5XXErrors"
  namespace           = "AWS/SageMaker"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  dimensions = {
    EndpointName = local.endpoint_name
    VariantName  = "primary"
  }
}
