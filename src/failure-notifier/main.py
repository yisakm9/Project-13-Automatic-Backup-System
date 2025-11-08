import json
import boto3
import os
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

sns_client = boto3.client('sns')

# Environment variable for the SNS topic ARN
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN')
if not SNS_TOPIC_ARN:
    raise ValueError("SNS_TOPIC_ARN environment variable is not set.")

def handler(event, context):
    """
    Lambda handler triggered by the failure SQS queue (DLQ).
    Formats a notification and publishes it to an SNS topic.
    """
    logger.info(f"Received failure event: {json.dumps(event)}")

    for record in event['Records']:
        try:
            message_body = record.get('body', '{}')
            
            # The body might be a JSON string from EventBridge
            try:
                sqs_body = json.loads(message_body)
                s3_detail = sqs_body.get('detail', {})
                bucket = s3_detail.get('bucket', {}).get('name', 'N/A')
                key = s3_detail.get('object', {}).get('key', 'N/A')
                reason = sqs_body.get('detail-type', 'Unknown Event')

                subject = f"Backup System Failure Alert: {reason}"
                message = (
                    f"A failure occurred in the automated backup system.\n\n"
                    f"Object: s3://{bucket}/{key}\n"
                    f"Reason: The event '{reason}' failed processing after multiple retries.\n\n"
                    f"This message was moved to the Dead-Letter Queue and requires manual investigation.\n\n"
                    f"Full SQS Message Body:\n{json.dumps(sqs_body, indent=2)}"
                )

            except json.JSONDecodeError:
                # If the body is not JSON, treat it as a plain string
                subject = "Backup System Failure Alert: Unhandled Error"
                message = (
                    f"An un-parsable message was received in the failure queue.\n\n"
                    f"Manual investigation is required.\n\n"
                    f"Raw Message Body:\n{message_body}"
                )

            # Publish the formatted message to SNS
            sns_client.publish(
                TopicArn=SNS_TOPIC_ARN,
                Subject=subject,
                Message=message
            )
            logger.info(f"Successfully published notification to SNS topic: {SNS_TOPIC_ARN}")

        except Exception as e:
            logger.error(f"Failed to process and notify for a record: {str(e)}")
            # We must not re-raise the exception here, or this function will
            # create an infinite loop with its own DLQ.
    
    return {
        'statusCode': 200,
        'body': json.dumps('Failure notification processing complete.')
    }