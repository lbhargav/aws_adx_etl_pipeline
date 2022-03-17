terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.25.0"
    }
  }
}

resource "aws_iam_role" "adx_heartbeat_dynamodb_role" {
  name = "adx_heartbeat_dynamodb_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "dynamodb.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "adx_heartbeat_dynamodb_policy" {
  name = "adx_heartbeat_dynamodb_policy"
  role = aws_iam_role.adx_heartbeat_dynamodb_role.id
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
        Action   = "states:*",
        Resource = "*"
      },
      {
        Effect   = "Allow",
        Action   = "cloudwatch:*",
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = "s3:*",
        Resource = [
          var.adx_s3_bucket_arn,
          join("", [var.adx_s3_bucket_arn, "/*"])
        ]
      }
    ]
  })
}

resource "aws_dynamodb_table" "adx_heartbeat_table" {
  name           = "adx_heartbeat_table"
  billing_mode   = "PROVISIONED"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "dataset_id"
  range_key      = "revision_id"

  attribute {
    name = "dataset_id"
    type = "S"
  }

  attribute {
    name = "revision_id"
    type = "S"
  }

  attribute {
    name = "glue_job_action_status"
    type = "S"
  }

   global_secondary_index {
    name               = "glue_job_action_status_index"
    hash_key           = "glue_job_action_status"
    write_capacity     = 10
    read_capacity      = 10
    projection_type    = "ALL"
//    non_key_attributes = ["dataset_id", ]
  }


  ttl {
    attribute_name = "TimeToExist"
    enabled        = true
  }

  tags = {
    Name        = "adx_heartbeat_table"
    Environment = "development"
  }
}