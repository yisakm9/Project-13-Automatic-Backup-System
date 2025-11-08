import json
import boto3
import os
import logging
from botocore.exceptions import ClientError # Import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3_client = boto3.client('s3')

# Environment variables for replica region
REPLICA_AWS_REGION = os.environ.get('REPLICA_AWS_REGION')
if not REPLICA_AWS_REGION:
    raise ValueError("REPLICA_AWS_REGION environment variable is not set.")

s3_replica_client = boto3.client('s3', region_name=REPLICA_AWS_REGION)

def get_s3_object_etag(s3, bucket, key):
    """Fetches the ETag of an S3 object, handling 'Not Found' errors gracefully."""
    try:
        response = s3.head_object(Bucket=bucket, Key=key)
        return response['ETag'].strip('"')
    except ClientError as e:
        # This is the expected race condition: the replica is not there yet.
        if e.response['Error']['Code'] == '404':
            logger.warning(f"Object not found yet in s3://{bucket}/{key}. This is expected during replication lag.")
            # We return None, and the handler will raise an exception to trigger the SQS retry.
            return None
        else:
            # For other errors like permissions (403), log as an error and let it fail.
            logger.error(f"A ClientError occurred for s3://{bucket}/{key}: {str(e)}")
            return None
    except Exception as e:
        logger.error(f"An unexpected error occurred getting ETag for s3://{bucket}/{key}: {str(e)}")
        return None

def handler(event, context):
    """
    Lambda handler triggered by SQS. Parses S3 event, gets primary and replica
    object ETags, and compares them to verify integrity.
    """
    logger.info(f"Received event: {json.dumps(event)}")

    for record in event['Records']:
        try:
            sqs_body = json.loads(record['body'])
            s3_detail = sqs_body['detail']

            primary_bucket = s3_detail['bucket']['name']
            object_key = s3_detail['object']['key']
            
            replica_bucket = primary_bucket.replace("primary", "replica")

            logger.info(f"Processing object s3://{primary_bucket}/{object_key}")
            logger.info(f"Replica bucket identified as: {replica_bucket}")

            primary_etag = get_s3_object_etag(s3_client, primary_bucket, object_key)
            replica_etag = get_s3_object_etag(s3_replica_client, replica_bucket, object_key)

            if not primary_etag or not replica_etag:
                # This will be triggered if the replica is not found yet.
                # Re-raising the error signals SQS to retry the message.
                raise ValueError("Could not retrieve ETag for one or both objects. Will retry.")

            if primary_etag == replica_etag:
                logger.info(f"SUCCESS: Checksum validation passed for {object_key}. ETag: {primary_etag}")
            else:
                logger.error(f"FAILURE: Checksum mismatch for {object_key}. Primary: {primary_etag}, Replica: {replica_etag}")
                raise ValueError(f"Checksum validation failed for {object_key}")

        except Exception as e:
            logger.error(f"Error processing SQS record: {str(e)}")
            raise e
            
    return {
        'statusCode': 200,
        'body': json.dumps('Processing complete.')
    }