terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.25.0"
    }
  }
}

data "archive_file" "adx_heartbeat_zip_file" {
  type        = "zip"
  source_dir = "${path.module}/index"
  output_path = "${path.module}/index.zip"
}

# Create Lambda function using Python code included in index.zip
resource "aws_lambda_function" "adx_heartbeat_export_lambda" {
  function_name    = "adx_heartbeat_export_lambda"
  filename         = "${data.archive_file.adx_heartbeat_zip_file.output_path}"
  source_code_hash = "${data.archive_file.adx_heartbeat_zip_file.output_base64sha256}"
//  filename         = "index.zip"
//  source_code_hash = filebase64sha256("index.zip")
  handler          = "export_lambda.handler"
  environment {
    variables = {
      S3_BUCKET          = var.adx_s3_bucket
      INBOUND_SQS_QUEUE  = var.adx_inbound_sqs_queue
      DYNAMODB_TABLE = var.adx_dynamodb_table
    }
  }
  role    = aws_iam_role.RoleGetNewRevision.arn
  runtime = "python3.7"
  timeout = 180
}

# Create Lambda function using Python code included in index.zip
resource "aws_lambda_function" "adx_heartbeat_glue_job_poller_lambda" {
  function_name    = "adx_heartbeat_glue_job_poller_lambda"
  filename         = "${data.archive_file.adx_heartbeat_zip_file.output_path}"
  source_code_hash = "${data.archive_file.adx_heartbeat_zip_file.output_base64sha256}"
//  filename         = "index.zip"
//  source_code_hash = filebase64sha256("index.zip")
  handler          = "glue_job_poller_lambda.handler"
  environment {
    variables = {
      GLUE_JOB = var.adx_glue_job_name
    }
  }
  role    = aws_iam_role.RoleGetNewRevision.arn
  runtime = "python3.7"
  timeout = 180
}

# Create Lambda function using Python code included in index.zip
resource "aws_lambda_function" "FunctionGetNewRevision" {
  function_name    = "FunctionGetNewRevision"
  filename         = "${data.archive_file.adx_heartbeat_zip_file.output_path}"
  source_code_hash = "${data.archive_file.adx_heartbeat_zip_file.output_base64sha256}"
//  filename         = "index.zip"
//  source_code_hash = filebase64sha256("index.zip")
  handler          = "index.handler"
  environment {
    variables = {
      S3_BUCKET          = var.adx_s3_bucket
      INBOUND_SQS_QUEUE  = var.adx_inbound_sqs_queue
      SFN_STATE_MACHINE  = var.adx_state_machine_arn

    }
  }
  role    = aws_iam_role.RoleGetNewRevision.arn
  runtime = "python3.7"
  timeout = 180
}

# Attach LambdaBasicExecutionRole AWS Managed Policy to Lambda Execution Role(RoleGetNewRevision)
resource "aws_iam_role_policy_attachment" "RoleGetNewRevisionAttachment" {
  role       = aws_iam_role.RoleGetNewRevision.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Provide permission for EventBridge to invoke Lambda function
resource "aws_lambda_permission" "LambdaInvokePermission" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.FunctionGetNewRevision.function_name
  principal     = "events.amazonaws.com"
  source_arn    = var.adx_new_revision_event_rule
}

# Create Lambda Execution Role
resource "aws_iam_role" "RoleGetNewRevision" {
  name = "RoleGetNewRevision"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Add Required Policies to Lambda Execution Role
resource "aws_iam_role_policy" "RoleGetNewRevisionPolicy" {
  name = "RoleGetNewRevisionPolicy"
  role = aws_iam_role.RoleGetNewRevision.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dataexchange:StartJob",
          "dataexchange:CreateJob",
          "dataexchange:GetJob",
          "dataexchange:ListRevisionAssets",
          "dataexchange:GetAsset",
          "dataexchange:GetRevision"
        ]
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = "s3:GetObject",
        Resource = "arn:aws:s3:::*aws-data-exchange*"
        Condition = {
          "ForAnyValue:StringEquals" = {
            "aws:CalledVia" = [
              "dataexchange.amazonaws.com"
            ]
          }
        }
      },
      {
        Effect   = "Allow",
        Action   = "sns:*",
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = "sqs:*",
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = "glue:*",
        Resource = "*"
      },
       {
        Effect   = "Allow",
        Action   = "dynamodb:*",
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = "states:*",
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = "s3:PutObject",
        Resource = [
          var.adx_s3_bucket_arn,
          join("", [var.adx_s3_bucket_arn, "/*"])
        ]
      }
    ]
  })
}

# Setup SQS Queue Trigger for S3 Export Lambda
resource "aws_lambda_event_source_mapping" "s3ExportLambdaTrigger" {
  event_source_arn = var.adx_inbound_sqs_queue_arn
  function_name    = aws_lambda_function.FunctionGetNewRevision.function_name
}