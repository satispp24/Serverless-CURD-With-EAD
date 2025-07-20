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
    Lambda function to handle WebSocket connect events
    """
    try:
        # Get connection ID
        connection_id = event.get('requestContext', {}).get('connectionId')
        
        if not connection_id:
            logger.error("No connection ID found in event")
            return {'statusCode': 400, 'body': 'No connection ID'}
        
        # Store connection ID in DynamoDB
        # Client can send requestId as a query parameter to associate with their connection
        request_id = event.get('queryStringParameters', {}).get('requestId', '')
        
        item = {
            'connectionId': connection_id,
            'timestamp': int(boto3.client('dynamodb').get_item(
                TableName='DynamoDB',
                Key={'id': {'S': 'id'}}
            )['Item']['timestamp']['N']),
            'requestId': request_id
        }
        
        # Store in DynamoDB
        table.put_item(Item=item)
        
        logger.info(f"Connection {connection_id} stored with requestId {request_id}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Connected'})
        }
        
    except Exception as e:
        logger.error(f"Error handling connection: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }