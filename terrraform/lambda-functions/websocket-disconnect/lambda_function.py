import json
import os
import boto3
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ.get('CONNECTIONS_TABLE_NAME'))

def lambda_handler(event, context):
    """
    Lambda function to handle WebSocket disconnect events
    """
    try:
        # Get connection ID
        connection_id = event.get('requestContext', {}).get('connectionId')
        
        if not connection_id:
            logger.error("No connection ID found in event")
            return {'statusCode': 400, 'body': 'No connection ID'}
        
        # Remove connection ID from DynamoDB
        table.delete_item(Key={'connectionId': connection_id})
        
        logger.info(f"Connection {connection_id} removed")
        
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Disconnected'})
        }
        
    except Exception as e:
        logger.error(f"Error handling disconnection: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }