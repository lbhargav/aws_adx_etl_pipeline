terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.25.0"
    }
  }
}

# Configure AWS Provider account & target region
provider "aws" {
  region  = "us-east-1"
}

module "adx_heartbeat_cloudwatch" {
  source = "../terraform/terraform_adx_common/cloudwatch"
  datasetID = "aae4c2cd145a48454f9369d4a4db5c66"
  adx_inbound_sqs_queue_arn = "${module.adx_heartbeat_sqs.adx_inbound_sqs_queue_arn}"
}

module "adx_heartbeat_sqs" {
  source = "../terraform/terraform_adx_common/sqs"
}

module "adx_heartbeat_lambda" {
  source = "../terraform/terraform_adx_common/lambda"
  adx_s3_bucket_id = "${module.adx_heartbeat_s3.adx_s3_bucket_id}"
  adx_s3_bucket_arn = "${module.adx_heartbeat_s3.adx_s3_bucket_arn}"
  adx_s3_bucket = "${module.adx_heartbeat_s3.adx_s3_bucket}"
  adx_inbound_sqs_queue = "${module.adx_heartbeat_sqs.adx_inbound_sqs_queue_id}"
  adx_dynamodb_table = "${module.adx_heartbeat_dynamodb.adx_dynamodb_table}"
  adx_glue_job_name = "${module.adx_heartbeat_glue.adx_glue_job_name}"
  adx_new_revision_event_rule = "${module.adx_heartbeat_cloudwatch.adx_new_revision_event_rule}"
  adx_inbound_sqs_queue_arn = "${module.adx_heartbeat_sqs.adx_inbound_sqs_queue_arn}"
  adx_state_machine_arn = "${module.adx_heartbeat_step_function.adx_state_machine_arn}"
}

module "adx_heartbeat_step_function" {
  source = "../terraform/terraform_adx_common/step_function"
  adx_s3_bucket_id = "${module.adx_heartbeat_s3.adx_s3_bucket_id}"
  adx_s3_bucket_arn = "${module.adx_heartbeat_s3.adx_s3_bucket_arn}"
  adx_s3_bucket = "${module.adx_heartbeat_s3.adx_s3_bucket}"
  adx_glue_job_poller_lambda_arn = "${module.adx_heartbeat_lambda.adx_glue_job_poller_lambda_arn}"
  adx_export_lambda_arn = "${module.adx_heartbeat_lambda.adx_export_lambda_arn}"
}

module "adx_heartbeat_dynamodb" {
  source = "../terraform/terraform_adx_common/dynamodb"
  adx_s3_bucket_arn = "${module.adx_heartbeat_s3.adx_s3_bucket_arn}"
}

module "adx_heartbeat_s3" {
  source = "../terraform/terraform_adx_common/s3"
}

module "adx_heartbeat_glue" {
  source = "../terraform/terraform_adx_common/glue"
  adx_outbound_queue_id = "${module.adx_heartbeat_sqs.adx_outbound_queue_id}"
  adx_s3_bucket_id = "${module.adx_heartbeat_s3.adx_s3_bucket_id}"
  adx_s3_bucket_arn = "${module.adx_heartbeat_s3.adx_s3_bucket_arn}"
  adx_s3_bucket = "${module.adx_heartbeat_s3.adx_s3_bucket}"
  adx_dynamodb_table = "${module.adx_heartbeat_dynamodb.adx_dynamodb_table}"
}

# Require dataset ID and initial revision ID to be input before the deployment can take place (the dataset must be subscribed to manually in the AWS Console)
variable "datasetID" {
  type        = string
  description = "ADX Heart Beat Test dataset"
}

variable "revisionID" {
  type        = string
  description = "REQUIRED: the ID for an initial Revision to download immediately."
}
