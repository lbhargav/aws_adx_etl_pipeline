import sys
import datetime

from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
import boto3
import json
from boto3.dynamodb.conditions import Key, Attr

DELIMITER = "/"

time_stamp = datetime.datetime.now()
destination_folder = "adx-heartbeat_csv/" + str(time_stamp.year) + DELIMITER + str(time_stamp.month) + DELIMITER + str(
                        time_stamp.day) + DELIMITER + str(time_stamp.hour) + DELIMITER
## @params: [JOB_NAME]
args = getResolvedOptions(sys.argv, ['JOB_NAME', 'S3_BUCKET', 'OUTBOUND_SQS_QUEUE', 'DYNAMODB_TABLE'])

outbound_sqs_queue = args[
    'OUTBOUND_SQS_QUEUE']
destination_bucket = 's3://' + args['S3_BUCKET']
dynamodb_table_name = args['DYNAMODB_TABLE']

sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

sqs = boto3.Session().client(service_name='sqs')

URI = sc._gateway.jvm.java.net.URI
Path = sc._gateway.jvm.org.apache.hadoop.fs.Path
FileSystem = sc._gateway.jvm.org.apache.hadoop.fs.FileSystem
fs = FileSystem.get(URI(destination_bucket), sc._jsc.hadoopConfiguration())

dynamodb_client = boto3.resource('dynamodb')

table = dynamodb_client.Table(dynamodb_table_name)

response = table.query(KeyConditionExpression=Key('dataset_id').eq('aae4c2cd145a48454f9369d4a4db5c66'),
                       FilterExpression=Attr('glue_job_action_status').eq('READY'))

for item in response['Items']:
    dataset_id = item['dataset_id']
    revision_id = item['revision_id']
    dataFilesMap = item['dataFilesMap']
    asset_s3_info = dataFilesMap.get("heartbeat")
    for asset in asset_s3_info:
        file_path = destination_bucket + DELIMITER + str(asset.get('key'))
        print(file_path)
        dataSource0 = glueContext.create_dynamic_frame.from_options(format_options={"jsonPath": "", "multiline": False},
                                                                    connection_type="s3", format="json",
                                                                    connection_options={"paths": [file_path]},
                                                                    transformation_ctx="DataSource0")
        print(dataSource0.toDF().show())

        applymapping1 = ApplyMapping.apply(frame=dataSource0, mappings=[
            ("timestampssincelastrevision", "array", "timestampssincelastrevision", "string")],
                                           transformation_ctx="applymapping1")

        desination_file_path = destination_bucket + DELIMITER + destination_folder + dataset_id + DELIMITER + revision_id + DELIMITER

        applymapping1.toDF().coalesce(1).write.mode('append').option("header", "true").csv(desination_file_path)

        created_file_path = fs.globStatus(Path(desination_file_path + "part*.csv"))[0].getPath()

        asset_name = file_path.split('/')[-1]
        asset_path = desination_file_path + str(asset_name.split(".")[0]) + '.csv'
        fs.rename(created_file_path, Path(asset_path))
        renamed_file_path = fs.globStatus(Path(desination_file_path + "*.csv"))[0].getPath()
        print(renamed_file_path)
        asset['key'] = str(renamed_file_path)

        message = {}
        message['dataset_id'] = dataset_id
        message['revision_id'] = revision_id
        message['dataFilesMap'] = dataFilesMap
        sqs.send_message(QueueUrl=outbound_sqs_queue, MessageBody=json.dumps(message), MessageGroupId=dataset_id)

        # print(revision_asset_info)

        table.update_item(
            Key={
                'dataset_id': dataset_id,
                'revision_id': revision_id
            },
            UpdateExpression="set glue_job_action_status = :glue_job_action_status, dataFilesCSVMap = :dataFilesCSVMap",
            ExpressionAttributeValues={
                ':glue_job_action_status': "SUCCESS",
                ':dataFilesCSVMap': asset_s3_info
            },
            ReturnValues="UPDATED_NEW"
        )

job.commit()