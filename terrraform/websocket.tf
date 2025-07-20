resource "aws_apigatewayv2_api" "websocket_api" {
  name                       = "${var.project_name}-websocket-api"
  protocol_type              = "WEBSOCKET"
  route_selection_expression = "$request.body.action"

  tags = {
    Name        = "${var.project_name}-websocket-api"
    Environment = var.environment
  }
}

# WebSocket API Routes
resource "aws_apigatewayv2_route" "connect_route" {
  api_id    = aws_apigatewayv2_api.websocket_api.id
  route_key = "$connect"
  target    = "integrations/${aws_apigatewayv2_integration.connect_integration.id}"
}

resource "aws_apigatewayv2_route" "disconnect_route" {
  api_id    = aws_apigatewayv2_api.websocket_api.id
  route_key = "$disconnect"
  target    = "integrations/${aws_apigatewayv2_integration.disconnect_integration.id}"
}

resource "aws_apigatewayv2_route" "default_route" {
  api_id    = aws_apigatewayv2_api.websocket_api.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.default_integration.id}"
}

# WebSocket API Integrations
resource "aws_apigatewayv2_integration" "connect_integration" {
  api_id                    = aws_apigatewayv2_api.websocket_api.id
  integration_type          = "AWS_PROXY"
  integration_uri           = aws_lambda_function.websocket_connect_lambda.invoke_arn
  content_handling_strategy = "CONVERT_TO_TEXT"
  integration_method        = "POST"
}

resource "aws_apigatewayv2_integration" "disconnect_integration" {
  api_id                    = aws_apigatewayv2_api.websocket_api.id
  integration_type          = "AWS_PROXY"
  integration_uri           = aws_lambda_function.websocket_disconnect_lambda.invoke_arn
  content_handling_strategy = "CONVERT_TO_TEXT"
  integration_method        = "POST"
}

resource "aws_apigatewayv2_integration" "default_integration" {
  api_id                    = aws_apigatewayv2_api.websocket_api.id
  integration_type          = "AWS_PROXY"
  integration_uri           = aws_lambda_function.websocket_default_lambda.invoke_arn
  content_handling_strategy = "CONVERT_TO_TEXT"
  integration_method        = "POST"
}

# WebSocket API Deployment
resource "aws_apigatewayv2_deployment" "websocket_deployment" {
  api_id      = aws_apigatewayv2_api.websocket_api.id
  description = "WebSocket API Deployment"

  depends_on = [
    aws_apigatewayv2_route.connect_route,
    aws_apigatewayv2_route.disconnect_route,
    aws_apigatewayv2_route.default_route
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_apigatewayv2_stage" "websocket_stage" {
  api_id      = aws_apigatewayv2_api.websocket_api.id
  name        = var.environment
  auto_deploy = true

  default_route_settings {
    throttling_burst_limit = 100
    throttling_rate_limit  = 50
  }

  tags = {
    Name        = "${var.project_name}-websocket-stage"
    Environment = var.environment
  }
}

# DynamoDB table to store WebSocket connections
resource "aws_dynamodb_table" "connections_table" {
  name           = "${var.project_name}-connections"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "connectionId"
  
  attribute {
    name = "connectionId"
    type = "S"
  }
  
  attribute {
    name = "requestId"
    type = "S"
  }
  
  global_secondary_index {
    name               = "requestId-index"
    hash_key           = "requestId"
    projection_type    = "ALL"
  }

  tags = {
    Name        = "${var.project_name}-connections-table"
    Environment = var.environment
  }
}

