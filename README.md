# aws_adx_etl_pipeline

![stepfunctions_graph (2)](https://user-images.githubusercontent.com/18109881/122941829-9792ce80-d32a-11eb-9045-ff12b0a5f689.png)

This sample shows how to set up an AWS Lambda function which will automatically export all newly published revisions for a given Data Set to S3. All infrastructure is setup using Terraform.

Logical Prerequisites:

Data Set ID for an active subscription to a Data Set on AWS Data Exchange
Revision ID for the target first revision to export
Technical Prerequisites:

Terraform is installed
AWS CLI is installed and has a profile configured with access to create IAM, S3, and Lambda resources and issue permissions to CloudWatch, S3, and DataExchange
The deployment will target us-east-1 and use the "default" AWS CLI profile by default. Update the "profile" and "region" configuration in the "provider" section of the terraform template to modify these defaults.

Please note that this sample is provided for demonstration and learning purposes only, and should be reviewed for alignment with organisational policies and best practices before any production use.

First Time Terraform Deployment
$ terraform init

Build and Deploy
$ terraform plan
$ terraform apply
