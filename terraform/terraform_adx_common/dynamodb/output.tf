output "adx_dynamodb_table" {
  value = aws_dynamodb_table.adx_heartbeat_table.name
}
