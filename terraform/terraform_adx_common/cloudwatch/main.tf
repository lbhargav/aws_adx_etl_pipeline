terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "~> 3.25.0"
    }
  }
}

# Create new EventBridge rule to trigger on the Revision Published To Data Set event .This is invocation
resource "aws_cloudwatch_event_rule" "NewRevisionEventRule" {
  name        = "NewRevisionEventRule"
  description = "New Revision Event"
  event_pattern = jsonencode({
    source      = ["aws.dataexchange"],
    detail-type = ["Revision Published To Data Set"],
    resources   = [var.datasetID]
  })
}

# Create trigger for EventBridge/Cloudwatch rule to SQS queue adx_sqs_queue .This is triggering target
resource "aws_cloudwatch_event_target" "TargetGetNewRevision" {
  rule      = aws_cloudwatch_event_rule.NewRevisionEventRule.name
  target_id = "TargetGetNewRevision"
  arn       = var.adx_inbound_sqs_queue_arn
  sqs_target {
    message_group_id = var.datasetID
  }
}
