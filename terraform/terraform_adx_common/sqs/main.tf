terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.25.0"
    }
  }
}

# Create SQS Queue "adx_sqs_queue"
resource "aws_sqs_queue" "adx_sqs_queue" {
  name                        = "adx_sqs_queue.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
  max_message_size            = 2048
  visibility_timeout_seconds  = 240
}

# Create policy "adx_sqs_queue_policy" and attach it to "adx_sqs_queue"
resource "aws_sqs_queue_policy" "adx_sqs_queue_policy" {
  queue_url = aws_sqs_queue.adx_sqs_queue.id
  policy    = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "sqspolicy",
  "Statement": [
    {
      "Sid": "First",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "sqs:*",
      "Resource": "${aws_sqs_queue.adx_sqs_queue.arn}"
    }
  ]
}
POLICY
}

# Create SQS Queue 'adx-s3export-new-revision-event-queue'
resource "aws_sqs_queue" "adx-s3export-new-revision-event-queue" {
  name                        = "adx-s3export-new-revision-event-queue.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
  max_message_size            = 2048
  visibility_timeout_seconds  = 600
}

# Create policy "adx-s3export-new-revision-event-queue-policy" and attach it to "adx-s3export-new-revision-event-queue"
resource "aws_sqs_queue_policy" "adx-s3export-new-revision-event-queue-policy" {
  queue_url = aws_sqs_queue.adx-s3export-new-revision-event-queue.id
  policy    = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "sqspolicy",
  "Statement": [
    {
      "Sid": "First",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "sqs:*",
      "Resource": "${aws_sqs_queue.adx-s3export-new-revision-event-queue.arn}"
    }
  ]
}
POLICY
}