import json
import boto3
import os
import logging

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
    """Fetches the ETag of an S3 object."""
    try:
        response = s3.head_object(Bucket=bucket, Key=key)
        # ETag is returned with quotes, which need to be stripped
        return response['ETag'].strip('"')
    except Exception as e:
        logger.error(f"Error getting ETag for s3://{bucket}/{key}: {str(e)}")
        return None

def handler(event, context):
    """
    Lambda handler triggered by SQS. Parses S3 event, gets primary and replica
    object ETags, and compares them to verify integrity.
    """
    logger.info(f"Received event: {json.dumps(event)}")

    for record in event['Records']:
        try:
            # The actual S3 event is a JSON string in the SQS message body
            sqs_body = json.loads(record['body'])
            s3_detail = sqs_body['detail']

            primary_bucket = s3_detail['bucket']['name']
            object_key = s3_detail['object']['key']
            
            # Construct replica bucket name based on convention
            # Assumes 'primary' is replaced with 'replica'
            replica_bucket = primary_bucket.replace("primary", "replica")

            logger.info(f"Processing object s3://{primary_bucket}/{object_key}")
            logger.info(f"Replica bucket identified as: {replica_bucket}")

            # Get ETags for both primary and replica objects
            primary_etag = get_s3_object_etag(s3_client, primary_bucket, object_key)
            replica_etag = get_s3_object_etag(s3_replica_client, replica_bucket, object_key)

            if not primary_etag or not replica_etag:
                # Failure will be handled by the DLQ after retries
                raise ValueError("Could not retrieve ETag for one or both objects.")

            if primary_etag == replica_etag:
                logger.info(f"SUCCESS: Checksum validation passed for {object_key}. ETag: {primary_etag}")
                # In a more advanced workflow, you might delete the message here,
                # but the SQS-Lambda integration handles this automatically on success.
            else:
                logger.error(f"FAILURE: Checksum mismatch for {object_key}. Primary: {primary_etag}, Replica: {replica_etag}")
                # This will cause the function to error out, triggering SQS retries and eventually the DLQ
                raise ValueError(f"Checksum validation failed for {object_key}")

        except Exception as e:
            logger.error(f"Error processing SQS record: {str(e)}")
            # Re-raise the exception to signal failure to the SQS-Lambda integration
            raise e
            
    return {
        'statusCode': 200,
        'body': json.dumps('Processing complete.')
    }