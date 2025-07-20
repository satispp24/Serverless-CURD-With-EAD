# Event-Driven Architecture for Serverless CRUD Application

## Overview

This document describes the event-driven architecture implemented for the serverless CRUD application. The architecture leverages AWS SQS to decouple the API Gateway from Lambda functions, providing better scalability, resilience, and asynchronous processing capabilities.

## Architecture Diagram

```
┌────────┐                                                                                  
│ Client │                                                                                  
│        │                                                                                  
└───┬────┘                                                                                  
    │                                                                                       
    ├────────────────┐                                                                      
    │                ▼                                                                      
    │         ┌──────────────┐                                                              
    │         │ WebSocket API│                                                              
    │         │              │                                                              
    │         │ • $connect   │                                                              
    │         │ • $disconnect│                                                              
    │         │ • $default   │                                                              
    │         └──────┬───────┘                                                              
    │                │                                                                      
    │                ▼                                                                      
    │         ┌──────────────┐                                                              
    │         │  WebSocket   │                                                              
    │         │   Lambdas    │                                                              
    │         │              │                                                              
    │         │ • Connect    │                                                              
    │         │ • Disconnect │                                                              
    │         │ • Default    │                                                              
    │         └──────┬───────┘                                                              
    │                │                                                                      
    │                ▼                                                                      
    │         ┌──────────────┐                                                              
    │         │ Connections  │                                                              
    │         │   DynamoDB   │                                                              
    │         │              │                                                              
    │         │ • connectionId│                                                             
    │         │ • requestId  │                                                              
    │         └──────────────┘                                                              
    │                ▲                                                                      
    │                │                                                                      
    │                │                                                                      
    ▼                │                                                                      
┌─────────────┐      │      ┌──────────────┐     ┌──────────────┐     ┌──────────┐          
│ REST API    │      │      │ Notification │     │ Notification │     │WebSocket │          
│ Gateway     │      └──────│    Lambda    │◀────│     SQS      │◀────│ Messages │          
│             │             │              │     │              │     │          │          
│ • /items    │             └──────────────┘     └──────────────┘     └──────────┘          
│ • /items/{id}│                                        ▲                                   
└──────┬──────┘                                        │                                   
       │                                               │                                   
       ▼                                               │                                   
┌──────────────┐                                       │                                   
│ CRUD SQS     │                                       │                                   
│ Queue        │                                       │                                   
│              │                                       │                                   
│ • Message    │                                       │                                   
│   Filtering  │                                       │                                   
└──────┬───────┘                                       │                                   
       │                                               │                                   
       ├───────────────┬────────────────┬──────────────┘                                   
       │               │                │                                                  
       ▼               ▼                ▼                                                  
┌──────────────┐ ┌──────────────┐ ┌──────────────┐                                         
│ Create       │ │ Read         │ │ Update/Delete│                                         
│ Lambda       │ │ Lambda       │ │ Lambda       │                                         
│              │ │              │ │              │                                         
│ • Filter:    │ │ • Filter:    │ │ • Filter:    │                                         
│   operation= │ │   operation= │ │   operation= │                                         
│   create     │ │   get/list   │ │   update/del │                                         
└──────┬───────┘ └──────┬───────┘ └──────┬───────┘                                         
       │                │                │                                                  
       │                │                │                                                  
       ▼                ▼                ▼                                                  
┌──────────────────────────────────────────────┐                                            
│                 DynamoDB                     │                                            
│                                              │                                            
│ • CRUD Items Table                           │                                            
│ • Connections Table                          │                                            
└──────────────────────────────────────────────┘                                            
       │                │                │                                                  
       │                │                │                                                  
       └────────────────┼────────────────┘                                                  
                        │                                                                   
                        ▼                                                                   
                 ┌──────────────┐                                                           
                 │ Dead Letter  │                                                           
                 │ Queue (DLQ)  │                                                           
                 │              │                                                           
                 │ • Failed     │                                                           
                 │   Messages   │                                                           
                 └──────────────┘                                                           
```

## Key Components

### API Gateway
- Receives HTTP requests from clients
- Validates and transforms requests
- Routes requests to appropriate SQS queues
- Returns immediate 202 Accepted response with request ID

### WebSocket API
- Maintains persistent connections with clients
- Enables real-time notifications
- Sends operation completion acknowledgments
- Allows clients to subscribe to specific request IDs

### SQS Queue
- Single queue for all CRUD operations with operation type in message
- Message filtering to route to appropriate Lambda functions
- Decouples API Gateway from Lambda functions
- Provides buffering during traffic spikes
- Enables retry capabilities
- Dead Letter Queue (DLQ) for failed message processing

### Lambda Functions
- Triggered by SQS events with message filtering
- Each function processes specific operation types
- Execute business logic based on operation
- Interact with DynamoDB
- Log operations to CloudWatch

### DynamoDB
- Persistent storage for items
- Scales automatically based on demand
- Point-in-time recovery for data protection

## Benefits of Event-Driven Architecture

1. **Decoupling**: API Gateway and Lambda functions are decoupled, allowing independent scaling and failure isolation.

2. **Resilience**: If Lambda functions are temporarily unavailable, messages are safely stored in SQS until processing is possible.

3. **Throttling Control**: SQS acts as a buffer during traffic spikes, preventing overwhelming downstream services.

4. **Retry Capability**: Failed operations can be retried automatically through SQS visibility timeout and redrive policies.

5. **Asynchronous Processing**: Clients receive immediate acknowledgment while processing happens asynchronously.

6. **Improved Monitoring**: Separate monitoring for queue depth, message age, and processing success/failure rates.

7. **Cost Optimization**: Lambda functions process messages in batches, potentially reducing invocation costs.

## Data Flow

### Create Item Flow
1. Client sends POST request to API Gateway
2. API Gateway transforms request, adds operation type "create", and sends message to SQS Queue
3. API Gateway returns 202 Accepted response with request ID
4. Client establishes WebSocket connection with request ID as parameter
5. Create Lambda function is triggered by SQS event (filtered by operation type)
6. Lambda processes the message and creates item in DynamoDB
7. Lambda sends notification to notification queue
8. Notification Lambda sends real-time acknowledgment to client via WebSocket
9. Lambda logs the operation to CloudWatch

### Read Items Flow
1. Client sends GET request to API Gateway
2. API Gateway transforms request, adds operation type "list" or "get", and sends message to SQS Queue
3. API Gateway returns 202 Accepted response with request ID
4. Read Lambda function is triggered by SQS event (filtered by operation type)
5. Lambda processes the message and retrieves items from DynamoDB
6. Lambda logs the operation to CloudWatch

### Update Item Flow
1. Client sends PUT request to API Gateway
2. API Gateway transforms request, adds operation type "update", and sends message to SQS Queue
3. API Gateway returns 202 Accepted response with request ID
4. Update Lambda function is triggered by SQS event (filtered by operation type)
5. Lambda processes the message and updates item in DynamoDB
6. Lambda logs the operation to CloudWatch

### Delete Item Flow
1. Client sends DELETE request to API Gateway
2. API Gateway transforms request, adds operation type "delete", and sends message to SQS Queue
3. API Gateway returns 202 Accepted response with request ID
4. Delete Lambda function is triggered by SQS event (filtered by operation type)
5. Lambda processes the message and deletes item from DynamoDB
6. Lambda logs the operation to CloudWatch

## Error Handling

1. **Message Processing Failures**: If Lambda fails to process a message, SQS will retry based on visibility timeout.

2. **Dead Letter Queue**: After multiple failed processing attempts, messages are sent to DLQ for investigation.

3. **CloudWatch Alarms**: Alarms can be set up for queue depth, message age, and DLQ message count.

4. **X-Ray Tracing**: End-to-end tracing for request flows to identify bottlenecks and failures.

## Considerations

1. **Response Latency**: The architecture introduces asynchronous processing, which means clients don't receive immediate results.

2. **Eventual Consistency**: Due to the asynchronous nature, there may be a delay between request and actual data changes.

3. **Message Size Limits**: SQS has a 256KB message size limit, which may require special handling for large payloads.

4. **Cost Implications**: Additional costs for SQS message processing and storage.

5. **Complexity**: The architecture is more complex than direct API Gateway to Lambda integration.

## Real-Time Notifications

### WebSocket Connection Flow
1. Client receives request ID from initial API call
2. Client establishes WebSocket connection with request ID as parameter
3. Connection Lambda stores connection ID and request ID in DynamoDB
4. When operation completes, notification is sent via WebSocket
5. Client receives real-time acknowledgment with operation result

### WebSocket Message Format
```json
{
  "requestId": "123e4567-e89b-12d3-a456-426614174000",
  "operation": "create|read|update|delete",
  "status": "success|error",
  "result": { /* operation result */ },
  "type": "notification"
}
```

### Benefits
- Real-time feedback for asynchronous operations
- Improved user experience with immediate notifications
- Reduced need for polling the API
- Efficient use of resources

## Future Enhancements

1. **SNS Notifications**: Add email or SMS notifications for critical operations

2. **Step Functions**: For complex workflows that require orchestration of multiple Lambda functions

3. **API Gateway Response Caching**: Implement caching for frequently accessed read operations

4. **SQS FIFO Queues**: For operations that require strict ordering guarantees

5. **WebSocket Authorization**: Add authentication and authorization to WebSocket connections