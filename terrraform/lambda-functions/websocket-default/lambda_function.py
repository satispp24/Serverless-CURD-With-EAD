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
    Lambda function to handle default WebSocket messages
    """
    try:
        # Get connection ID
        connection_id = event.get('requestContext', {}).get('connectionId')
        
        if not connection_id:
            logger.error("No connection ID found in event")
            return {'statusCode': 400, 'body': 'No connection ID'}
        
        # Parse message body
        body = json.loads(event.get('body', '{}'))
        
        # Echo the message back to the client
        api_gateway_management_api = boto3.client(
            'apigatewaymanagementapi',
            endpoint_url=f"https://{event['requestContext']['domainName']}/{event['requestContext']['stage']}"
        )
        
        api_gateway_management_api.post_to_connection(
            ConnectionId=connection_id,
            Data=json.dumps({
                'message': 'Echo: ' + json.dumps(body),
                'type': 'echo'
            })
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps({'message': 'Message received'})
        }
        
    except Exception as e:
        logger.error(f"Error handling message: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }