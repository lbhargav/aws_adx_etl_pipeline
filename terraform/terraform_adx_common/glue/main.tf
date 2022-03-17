terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.25.0"
    }
  }
}

resource "aws_iam_role" "adx_heartbeat_glue_job_role" {
  name = "adx_heartbeat_glue_job_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "glue.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "adx_heartbeat_glue_service" {
    role = "${aws_iam_role.adx_heartbeat_glue_job_role.id}"
    policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Add Required Policies to Glue Execution Role
resource "aws_iam_role_policy" "adx_heartbeat_glue_job_policy" {
  name = "adx_heartbeat_glue_job_policy"
  role = aws_iam_role.adx_heartbeat_glue_job_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
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
        Action   = "lambda:*",
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
        Action = "s3:*",
        Resource = "*"
      }
    ]
  })
}

# Upload an object
resource "aws_s3_bucket_object" "adx_heartbeat_glue_script_upload" {
  bucket = var.adx_s3_bucket_id
  key    = "aws_terraform/adx_heartbeat_glue_job.py"
  acl    = "private"  # or can be "public-read"
  source = "../terraform/terraform_adx_common/lambda/index/adx_heartbeat_glue_job.py"
  etag = filemd5("../terraform/terraform_adx_common/lambda/index/adx_heartbeat_glue_job.py")
}

resource "aws_glue_job" "adx_heartbeat_glue_job" {
  name         = "adx_heartbeat_glue_job"
  description  = "job-desc"
  role_arn     = aws_iam_role.adx_heartbeat_glue_job_role.arn
  max_capacity = 2
  max_retries  = 1
  timeout      = 60
  glue_version = "2.0"

  command {
    script_location = "s3://${var.adx_s3_bucket_id}/aws_terraform/adx_heartbeat_glue_job.py"
    python_version  = "3"
  }

  default_arguments = {
    "--job-language"          = "python"
    "--ENV"                   = "env"
    "--spark-event-logs-path" = "s3://${var.adx_s3_bucket_id}/aws_terraform/adx_heartbeat_glue_job/logs"
    "--job-bookmark-option"   = "job-bookmark-enable"
    "--enable-spark-ui"       = "true"
    "--S3_BUCKET" = var.adx_s3_bucket
    "--OUTBOUND_SQS_QUEUE" = var.adx_outbound_queue_id
    "--DYNAMODB_TABLE" = var.adx_dynamodb_table
  }

  execution_property {
    max_concurrent_runs = 1
  }
}

resource "aws_glue_trigger" "adx_heartbeat_glue_job_trigger" {
  name     = "adx_heartbeat_glue_job_trigger"
  schedule = "cron(05 * ? * * *)"
  type     = "SCHEDULED"

  actions {
    job_name = aws_glue_job.adx_heartbeat_glue_job.name
  }
}