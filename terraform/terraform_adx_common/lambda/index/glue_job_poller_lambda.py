import os
import time

os.environ['AWS_DATA_PATH'] = '/opt/'

import boto3

glue_job_name = os.environ['GLUE_JOB']

glue_client = boto3.client('glue')

def handler(event, context):
    response = glue_client.get_job_runs(JobName=glue_job_name, MaxResults=1)

    action_status = 'POLL'
    if len(response['JobRuns']) > 0:
        if response['JobRuns'][0]['JobRunState'] == 'SUCCEEDED':
            action_status = 'SUCCEEDED'
        elif response['JobRuns'][0]['JobRunState'] == 'FAILED':
            action_status = 'FAILED'
        else:
            time.sleep(5)

    return {'action_status' : action_status}
