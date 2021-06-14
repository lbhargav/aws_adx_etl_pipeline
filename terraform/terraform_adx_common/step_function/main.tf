terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.25.0"
    }
  }
}
resource "aws_sfn_state_machine" "adx_heartbeat_state_machine" {
  name     = "adx-heartbeat-state-machine"
  role_arn = aws_iam_role.adx_heartbeat_state_machine_role.arn

  definition = <<EOF
{
  "Comment": "A Hello World example of the Amazon States Language using Pass states",
  "StartAt": "Export Lambda",
  "States": {
    "Export Lambda": {
      "Type": "Task",
      "Resource": "${var.adx_export_lambda_arn}",
      "Next": "Glue Job Status Check?"
    },
    "Glue Job Status Check?": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.check_glue_job_status",
          "BooleanEquals": true,
          "Next": "Glue Job Poller Lambda"
        },
        {
          "Variable": "$.check_glue_job_status",
          "BooleanEquals": false,
          "Next": "Succeed State"
        }
      ]
    },
    "Glue Job Poller Lambda": {
      "Type": "Task",
      "Resource": "${var.adx_glue_job_poller_lambda_arn}",
      "Next": "Poll Glue Job?",
      "Retry": [
        {
          "ErrorEquals": [
            "Exception"
          ]
        }
      ]
    },
    "Poll Glue Job?": {
      "Type": "Choice",
      "Choices": [
        {
          "Variable": "$.action_status",
          "StringEquals": "SUCCEEDED",
          "Next": "Wait State"
        },
        {
          "Variable": "$.action_status",
          "StringEquals": "FAILED",
          "Next": "Fail State"
        },
        {
          "Variable": "$.action_status",
          "StringEquals": "POLL",
          "Next": "Glue Job Poller Lambda"
        }
      ]
    },
    "Wait State": {
      "Type": "Wait",
      "Seconds": 10,
      "Next": "Succeed State"
    },
    "Fail State": {
      "Type": "Fail",
      "Error": "ErrorCode",
      "Cause": "Caused By Message"
    },
    "Succeed State": {
      "Type": "Succeed"
    }
  }
}
EOF
}


resource "aws_iam_role" "adx_heartbeat_state_machine_role" {
  name = "adx_heartbeat_state_machine_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "states.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Add Required Policies to Glue Execution Role
resource "aws_iam_role_policy" "adx_heartbeat_step_function_policy" {
  name = "adx_heartbeat_step_function_policy"
  role = aws_iam_role.adx_heartbeat_state_machine_role.id
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