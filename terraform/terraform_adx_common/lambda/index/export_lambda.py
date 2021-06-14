import datetime
import os
import time
import json
import boto3

from collections import defaultdict

os.environ['AWS_DATA_PATH'] = '/opt/'

DELIMITER = "/"

region = os.environ['AWS_REGION']
destination_bucket = os.environ['S3_BUCKET']
inbound_sqs_queue = os.environ['INBOUND_SQS_QUEUE']
dynamodb_table_name = os.environ['DYNAMODB_TABLE']

time_stamp = datetime.datetime.now()
destination_folder = "adx-heartbeat/" + str(time_stamp.year) + DELIMITER + str(time_stamp.month) + DELIMITER + str(time_stamp.day) \
                     + DELIMITER + str(time_stamp.hour) + DELIMITER

# print("Region: {}".format(region))
# print("destination_folder: {}".format(destination_folder))

dataexchange = boto3.client(service_name='dataexchange', region_name=region)

dynamodb_client = boto3.resource('dynamodb', region_name=region)

s3 = boto3.client(service_name='s3',region_name=region)

sqs = boto3.Session().client(service_name='sqs',endpoint_url='https://sqs.us-east-1.amazonaws.com',)

glue_client = boto3.client('glue')

if not destination_bucket and not inbound_sqs_queue and not dynamodb_table_name:
    raise Exception("Environment variables. 'S3_BUCKET': {}, 'INBOUND_SQS_QUEUE': {}, "
                    "'DYNAMODB_TABLE': {} ".format(destination_bucket, inbound_sqs_queue, dynamodb_table_name))

table = dynamodb_client.Table(dynamodb_table_name)

def insert_item(dataset_id, revision_id):
    dataset_name = "heartbeat"
    table_assetlist = defaultdict(list)
    assets_list = []
    assets_details = dataexchange.list_revision_assets(DataSetId=dataset_id, RevisionId=revision_id)
    assets = assets_details['Assets']
    print('Assets: {}'.format(assets_details))
    for asset in assets:
        asset_name = asset['Name']
        print("Name: {}".format( asset_name))
        if asset_name.startswith('manifest'):
            metadata = asset_name
        else:
            asset_s3_info = {}
            asset_s3_info['bucket'] = destination_bucket
            asset_s3_info['key'] = destination_folder + dataset_id + DELIMITER + revision_id + DELIMITER + asset_name
            asset_s3_info['version'] = None
            assets_list.append(asset_s3_info.get('key'))
            table_assetlist[dataset_name].append(asset_s3_info)
    table.put_item(Item={
        'glue_job_action_status': 'READY',
        'dataset_id': dataset_id,
        'revision_id': revision_id,
        'export_time_stamp' : str(datetime.datetime.now()),
        'dataFilesMap' : table_assetlist,
        'metadata' : metadata
    })


def handler(event, context):
    print("Boto3 version: {}".format(boto3.__version__))
    print("Event: {}".format(event)) # debug logging

    if 'InitialInit' in event:
        dataset_id = event['InitialInit']['data_set_id']
        revision_ids = [event['InitialInit']['RevisionIds']]
        print ("Initial revision retrieved. dataset_id: {}, revision_ids: {}".format(dataset_id, revision_ids))

    else:
        for record in event['Records']:
            body = json.loads(record["body"])
            # message = json.loads(body['Message'])
            dataset_id = body['resources'][0]
            revision_ids = body['detail']['RevisionIds']
            print("Event from SQS retrieved. dataset_id: {}, revision_id: {}".format(dataset_id, revision_ids))

        # Used to store the Ids of the Jobs exporting the assets to S3.
        job_ids = set()

        # iterate all revision ids to get assets
    for revision_id in revision_ids:
        # Need set retry on a message if lambda fails 3 times to process msg, a cloudwatch event must be raised to notify
            print("revision_id: " + revision_id)
        # Start Jobs to export all the assets to S3.
        # try:
            ## Need to add revision asset. dataset
            revision_assets = dataexchange.list_revision_assets(DataSetId=dataset_id, RevisionId=revision_id)
            # Create the Job which exports assets to S3.

            export_job = dataexchange.create_job(
                Type='EXPORT_REVISIONS_TO_S3',
                Details={
                 'ExportRevisionsToS3': {
                    'DataSetId': dataset_id,
                # 'Encryption': {
                #     'KmsKeyArn': 'string',
                #     'Type': 'aws:kms'|'AES256'
                # },
                    'RevisionDestinations': [
                        { 'Bucket': destination_bucket, 'RevisionId': revision_id, 'KeyPattern': destination_folder + dataset_id + "/" + "${Revision.Id}/${Asset.Name}" }
                    ]
                  }
                }
            )
            # Start the Job and save the JobId.
            dataexchange.start_job(JobId=export_job['Id'])
            job_ids.add(export_job['Id'])

        # except InternalServerException as e:
        #     # Message will be 'in-flight' and will be available for consumption after visibility timeout expires.
        #     print('Error in processing revision: {}'.format(e.message))   #https://docs.aws.amazon.com/data-exchange/latest/apireference/v1-jobs.html

    # Iterate until all remaining workflow have reached a terminal state, or an error is found.
    completed_jobs = set()
    while job_ids != completed_jobs:
        for job_id in job_ids:
            if job_id in completed_jobs:
                continue
            get_job_response = dataexchange.get_job(JobId=job_id)
            if get_job_response['State'] == 'COMPLETED':
                print ("Job {} completed".format(job_id))
                completed_jobs.add(job_id)
                # publish event in SNS Topic
                message = insert_item(dataset_id,revision_ids[0])
                # sqs.send_message(QueueUrl=outbound_sqs_queue, MessageBody=message, MessageGroupId=dataset_id)
            if get_job_response['State'] == 'ERROR':
                job_errors = get_job_response['Errors']
                raise Exception('JobId: {} failed with errors:\n{}'.format(job_id, job_errors))
            # Sleep to ensure we don't get throttled by the GetJob API.
            time.sleep(0.2)

    check_glue_job_status = False
    if datetime.datetime.now().minute < 10:
        check_glue_job_status = True

    return {'check_glue_job_status': check_glue_job_status}

