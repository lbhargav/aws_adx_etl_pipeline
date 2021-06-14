import os

os.environ['AWS_DATA_PATH'] = '/opt/'

import json
import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.DEBUG)

region = os.environ['AWS_REGION']
inbound_sqs_queue = os.environ['INBOUND_SQS_QUEUE']
state_machine_arn = os.environ['SFN_STATE_MACHINE']

dataexchange = boto3.client(
    service_name='dataexchange',
    region_name=region
)

sfn_client = boto3.client('stepfunctions')

dynamodb_client = boto3.client('dynamodb')

s3 = boto3.client(
    service_name='s3',
    region_name=region
)

session = boto3.Session()

sqs = session.client(
    service_name='sqs',
    endpoint_url='https://sqs.us-east-1.amazonaws.com',
)

if not inbound_sqs_queue:
    raise Exception(
        "Environment variables. 'INBOUND_SQS_QUEUE': {} ".format(inbound_sqs_queue))

def handler(event, context):
    print("Boto3 version: {}".format(boto3.__version__))
    print("Event: {}".format(event))  # debug logging
    try:
        response = sfn_client.start_execution(stateMachineArn=state_machine_arn, input=json.dumps(event))
        logger.info("execution response: {}".format(response))
        return {
            'statusCode': 200,
            'body': json.dumps('State Machine started')
        }
    except Exception:
        logger.error("Error occurred while calling step function client")
