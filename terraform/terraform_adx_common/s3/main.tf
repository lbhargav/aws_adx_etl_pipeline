terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.25.0"
    }
  }
}

# Create S3 bucket to store exported data in
resource "aws_s3_bucket" "DataS3Bucket" {
  bucket_prefix = "datas3bucket"
}

# Apply all Public Access Block controls by default
resource "aws_s3_bucket_public_access_block" "DataS3BucketPublicAccessBlock" {
  bucket                  = aws_s3_bucket.DataS3Bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_object" "adx_s3_folder" {
  bucket       = aws_s3_bucket.DataS3Bucket.id
  key          = "adx-heartbeat/"
  content_type = "application/x-directory"
}
