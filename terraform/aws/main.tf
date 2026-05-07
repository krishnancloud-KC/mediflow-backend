terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ── S3 Bucket ──────────────────────────────────────────────

resource "aws_s3_bucket" "mediflow_backup" {
  bucket        = var.bucket_name
  force_destroy = true

  tags = {
    project = var.project_id
    env     = "dev"
  }
}

resource "aws_s3_bucket_public_access_block" "mediflow_backup" {
  bucket                  = aws_s3_bucket.mediflow_backup.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ── IAM Role for Lambda ─────────────────────────────────────

resource "aws_iam_role" "lambda_role" {
  name = "mediflow-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_s3" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}
# ── Lambda Function ─────────────────────────────────────────

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../../pipelines/export/lambda_function.py"
  output_path = "${path.module}/../../pipelines/export/lambda_function.zip"
}

resource "aws_lambda_function" "mediflow_export" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "mediflow-export"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.handler"
  runtime          = "python3.11"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      BUCKET_NAME = var.bucket_name
      PROJECT_ID  = var.project_id
    }
  }

  tags = {
    project = var.project_id
    env     = "dev"
  }
}

# ── Outputs ─────────────────────────────────────────────────

output "s3_bucket_name" {
  value = aws_s3_bucket.mediflow_backup.bucket
}

output "lambda_function_name" {
  value = aws_lambda_function.mediflow_export.function_name
}
