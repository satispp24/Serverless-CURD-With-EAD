import json
import boto3
import uuid
import os
import logging
from datetime import datetime
from botocore.exceptions import ClientError

# Configure logging
log_level = os.environ.get('LOG_LEVEL', 'INFO')
logger = logging.getLogger()
logger.setLevel(getattr(logging, log_level))

dynamodb = boto3.resource('dynamodb')
sqs = boto3.client('sqs')

def lambda_handler(event, context):
    """
    Lambda function to create an item in DynamoDB
    Triggered by SQS message
    """
    try:
        # Get table name from environment variable
        table_name = os.environ.get('TABLE_NAME')
        
        if not table_name:
            logger.error("TABLE_NAME environment variable not set")
            return {
                'statusCode': 500,
                'error': 'TABLE_NAME environment variable not set'
            }
        
        # Process SQS event
        logger.info(f"Received event: {json.dumps(event)}")
        
        # SQS can batch records, but we're using batch size 1
        for record in event.get('Records', []):
            # Extract message body
            try:
                message_body = record.get('body')
                if not message_body:
                    logger.error("Empty message body")
                    continue
                    
                # Parse the message body
                message_data = json.loads(message_body)
                
                # Check operation type
                operation = message_data.get('operation')
                if operation != 'create':
                    logger.warning(f"Unexpected operation type: {operation}. Expected 'create'.")
                    continue
                
                # Get payload
                item_data = message_data.get('payload', {})
                
                # Generate ID if not provided
                if 'id' not in item_data:
                    item_data['id'] = str(uuid.uuid4())
                
                # Add timestamp
                item_data['created_at'] = datetime.utcnow().isoformat()
                item_data['updated_at'] = datetime.utcnow().isoformat()
                
                # Get DynamoDB table
                table = dynamodb.Table(table_name)
                
                # Put item in DynamoDB
                logger.info(f"Creating item with ID: {item_data['id']}")
                table.put_item(Item=item_data)
                logger.info(f"Successfully created item with ID: {item_data['id']}")
                
                # Send notification to notification queue
                notification_queue_url = os.environ.get('NOTIFICATION_QUEUE_URL')
                if notification_queue_url:
                    # Extract request ID from the original message
                    request_id = message_data.get('requestId', str(uuid.uuid4()))
                    
                    # Send notification message
                    sqs.send_message(
                        QueueUrl=notification_queue_url,
                        MessageBody=json.dumps({
                            'requestId': request_id,
                            'operation': 'create',
                            'status': 'success',
                            'result': item_data
                        })
                    )
                    logger.info(f"Notification sent for requestId: {request_id}")
                else:
                    logger.warning("NOTIFICATION_QUEUE_URL not set, skipping notification")

                
            except json.JSONDecodeError as e:
                logger.error(f"Failed to parse message body: {str(e)}")
            except ClientError as e:
                logger.error(f"DynamoDB error: {str(e)}")
            except Exception as e:
                logger.error(f"Error processing record: {str(e)}")
        
        return {
            'statusCode': 200,
            'message': 'Processing complete'
        }
        
    except Exception as e:
        logger.error(f"Unhandled exception: {str(e)}")
        return {
            'statusCode': 500,
            'error': f'Internal server error: {str(e)}'
        }
