output "adx_inbound_sqs_queue_id" {
  value = aws_sqs_queue.adx_sqs_queue.id
}

output "adx_inbound_sqs_queue_arn" {
  value = aws_sqs_queue.adx_sqs_queue.arn
}

output "adx_outbound_queue_id" {
  value = aws_sqs_queue.adx-s3export-new-revision-event-queue.id
}