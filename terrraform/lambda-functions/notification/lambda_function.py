import json
import os
import boto3
import logging
from boto3.dynamodb.conditions import Key

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
connections_table = dynamodb.Table(os.environ.get('CONNECTIONS_TABLE_NAME'))

def lambda_handler(event, context):
    """
    Lambda function to send operation completion notifications to clients via WebSocket
    """
    try:
        # Process SQS event
        for record in event.get('Records', []):
            try:
                # Parse message body
                message_body = record.get('body')
                if not message_body:
                    logger.error("Empty message body")
                    continue
                
                # Parse the message body
                message_data = json.loads(message_body)
                
                # Extract request ID and operation result
                request_id = message_data.get('requestId')
                operation = message_data.get('operation')
                result = message_data.get('result')
                status = message_data.get('status', 'success')
                
                if not request_id:
                    logger.error("No request ID in message")
                    continue
                
                # Find connections associated with this request ID
                response = connections_table.query(
                    IndexName='requestId-index',
                    KeyConditionExpression=Key('requestId').eq(request_id)
                )
                
                connections = response.get('Items', [])
                logger.info(f"Found {len(connections)} connections for requestId {request_id}")
                
                if not connections:
                    logger.warning(f"No connections found for requestId {request_id}")
                    continue
                
                # Get API Gateway Management API endpoint from environment variable
                endpoint = os.environ.get('WEBSOCKET_API_ENDPOINT')
                if not endpoint:
                    logger.error("WEBSOCKET_API_ENDPOINT environment variable not set")
                    continue
                
                # Initialize API Gateway Management API client
                api_gateway_management_api = boto3.client(
                    'apigatewaymanagementapi',
                    endpoint_url=endpoint
                )
                
                # Send notification to each connected client
                for connection in connections:
                    connection_id = connection.get('connectionId')
                    try:
                        api_gateway_management_api.post_to_connection(
                            ConnectionId=connection_id,
                            Data=json.dumps({
                                'requestId': request_id,
                                'operation': operation,
                                'status': status,
                                'result': result,
                                'type': 'notification'
                            })
                        )
                        logger.info(f"Notification sent to connection {connection_id}")
                    except api_gateway_management_api.exceptions.GoneException:
                        # Connection is no longer valid, remove it
                        logger.info(f"Connection {connection_id} is gone, removing from table")
                        connections_table.delete_item(Key={'connectionId': connection_id})
                    except Exception as e:
                        logger.error(f"Error sending to connection {connection_id}: {str(e)}")
                
            except json.JSONDecodeError as e:
                logger.error(f"Failed to parse message body: {str(e)}")
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