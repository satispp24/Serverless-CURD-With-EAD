# Output values
output "api_gateway_url" {
  description = "Base URL for REST API Gateway"
  value       = aws_api_gateway_stage.crud_api_stage.invoke_url
}

output "websocket_api_url" {
  description = "WebSocket API endpoint URL"
  value       = "${aws_apigatewayv2_api.websocket_api.api_endpoint}/${aws_apigatewayv2_stage.websocket_stage.name}"
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.crud_table.name
}

output "lambda_function_names" {
  description = "Names of the Lambda functions"
  value = {
    create       = aws_lambda_function.create_lambda.function_name
    read         = aws_lambda_function.read_lambda.function_name
    update       = aws_lambda_function.update_lambda.function_name
    delete       = aws_lambda_function.delete_lambda.function_name
    notification = aws_lambda_function.notification_lambda.function_name
    ws_connect   = aws_lambda_function.websocket_connect_lambda.function_name
    ws_disconnect = aws_lambda_function.websocket_disconnect_lambda.function_name
  }
}

output "api_endpoints" {
  description = "API endpoints for CRUD operations"
  value = {
    rest_api = "${aws_api_gateway_stage.crud_api_stage.invoke_url}/items"
    websocket_api = "${aws_apigatewayv2_api.websocket_api.api_endpoint}/${aws_apigatewayv2_stage.websocket_stage.name}"
  }
}