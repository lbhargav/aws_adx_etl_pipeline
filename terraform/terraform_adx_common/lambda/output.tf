output "adx_glue_job_poller_lambda_arn" {
  value = aws_lambda_function.adx_heartbeat_glue_job_poller_lambda.arn
}

output "adx_export_lambda_arn" {
  value = aws_lambda_function.adx_heartbeat_export_lambda.arn
}
