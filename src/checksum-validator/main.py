import json
import boto3
import os
import logging
from botocore.exceptions import ClientError

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3_client = boto3.client('s3')

REPLICA_AWS_REGION = os.environ.get('REPLICA_AWS_REGION')
if not REPLICA_AWS_REGION:
    raise ValueError("REPLICA_AWS_REGION environment variable is not set.")

s3_replica_client = boto3.client('s3', region_name=REPLICA_AWS_REGION)

def get_s3_object_etag(s3, bucket, key):
    """
    Fetches the ETag of an S3 object and normalizes it by removing multipart upload suffixes.
    """
    try:
        response = s3.head_object(Bucket=bucket, Key=key)
        etag = response['ETag'].strip('"')

        # --- NORMALIZATION LOGIC ---
        # If the ETag contains a hyphen, it's likely a multipart upload ETag.
        # We strip the suffix (e.g., '-2') to get the core checksum for comparison.
        if '-' in etag:
            return etag.split('-')[0]
        
        return etag

    except ClientError as e:
        if e.response['Error']['Code'] == '404':
            logger.warning(f"Object not found yet in s3://{bucket}/{key}. This is expected during replication lag.")
            return None
        else:
            logger.error(f"A ClientError occurred for s3://{bucket}/{key}: {str(e)}")
            return None
    except Exception as e:
        logger.error(f"An unexpected error occurred getting ETag for s3://{bucket}/{key}: {str(e)}")
        return None

def handler(event, context):
    """
    Lambda handler triggered by SQS. Compares normalized ETags to verify integrity.
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
                raise ValueError("Could not retrieve ETag for one or both objects. Will retry.")

            if primary_etag == replica_etag:
                logger.info(f"SUCCESS: Checksum validation passed for {object_key}. Normalized ETag: {primary_etag}")
            else:
                logger.error(f"FAILURE: Checksum mismatch for {object_key}. Normalized Primary: {primary_etag}, Normalized Replica: {replica_etag}")
                raise ValueError(f"Checksum validation failed for {object_key}")

        except Exception as e:
            logger.error(f"Error processing SQS record: {str(e)}")
            raise e
            
    return {
        'statusCode': 200,
        'body': json.dumps('Processing complete.')
    }