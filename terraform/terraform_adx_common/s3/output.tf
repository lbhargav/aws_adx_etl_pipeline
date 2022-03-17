output "adx_s3_bucket_id" {
  value = aws_s3_bucket.DataS3Bucket.id
}

output "adx_s3_bucket_arn" {
  value = aws_s3_bucket.DataS3Bucket.arn
}

output "adx_s3_bucket" {
  value = aws_s3_bucket.DataS3Bucket.bucket
}