# API Gateway REST API
resource "aws_api_gateway_rest_api" "crud_api" {
  name        = "${var.project_name}-api"
  description = "CRUD API for ${var.project_name}"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name        = "${var.project_name}-api"
    Environment = var.environment
  }
}

# API Gateway Resource for items
resource "aws_api_gateway_resource" "items_resource" {
  rest_api_id = aws_api_gateway_rest_api.crud_api.id
  parent_id   = aws_api_gateway_rest_api.crud_api.root_resource_id
  path_part   = "items"
}

# API Gateway Resource for individual item (with ID)
resource "aws_api_gateway_resource" "item_resource" {
  rest_api_id = aws_api_gateway_rest_api.crud_api.id
  parent_id   = aws_api_gateway_resource.items_resource.id
  path_part   = "{id}"
}

# POST method for creating items
resource "aws_api_gateway_method" "create_method" {
  rest_api_id   = aws_api_gateway_rest_api.crud_api.id
  resource_id   = aws_api_gateway_resource.items_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

# GET method for reading all items
resource "aws_api_gateway_method" "read_all_method" {
  rest_api_id   = aws_api_gateway_rest_api.crud_api.id
  resource_id   = aws_api_gateway_resource.items_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

# GET method for reading single item
resource "aws_api_gateway_method" "read_method" {
  rest_api_id   = aws_api_gateway_rest_api.crud_api.id
  resource_id   = aws_api_gateway_resource.item_resource.id
  http_method   = "GET"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.id" = true
  }
}

# PUT method for updating items
resource "aws_api_gateway_method" "update_method" {
  rest_api_id   = aws_api_gateway_rest_api.crud_api.id
  resource_id   = aws_api_gateway_resource.item_resource.id
  http_method   = "PUT"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.id" = true
  }
}

# DELETE method for deleting items
resource "aws_api_gateway_method" "delete_method" {
  rest_api_id   = aws_api_gateway_rest_api.crud_api.id
  resource_id   = aws_api_gateway_resource.item_resource.id
  http_method   = "DELETE"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.id" = true
  }
}

# SQS integrations for API Gateway with single queue
resource "aws_api_gateway_integration" "create_integration" {
  rest_api_id = aws_api_gateway_rest_api.crud_api.id
  resource_id = aws_api_gateway_resource.items_resource.id
  http_method = aws_api_gateway_method.create_method.http_method

  type                    = "AWS"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${var.aws_region}:sqs:path/${data.aws_caller_identity.current.account_id}/${aws_sqs_queue.crud_queue.name}"
  credentials             = aws_iam_role.api_gateway_sqs_role.arn
  
  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }
  
  request_templates = {
    "application/json" = <<EOF
Action=SendMessage&MessageBody=$util.urlEncode({
  "operation": "create",
  "payload": $input.json('$')
})
EOF
  }
}

resource "aws_api_gateway_integration" "read_all_integration" {
  rest_api_id = aws_api_gateway_rest_api.crud_api.id
  resource_id = aws_api_gateway_resource.items_resource.id
  http_method = aws_api_gateway_method.read_all_method.http_method

  type                    = "AWS"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${var.aws_region}:sqs:path/${data.aws_caller_identity.current.account_id}/${aws_sqs_queue.crud_queue.name}"
  credentials             = aws_iam_role.api_gateway_sqs_role.arn
  
  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }
  
  request_templates = {
    "application/json" = <<EOF
Action=SendMessage&MessageBody=$util.urlEncode({
  "operation": "list",
  "queryParams": $input.json('$')
})
EOF
  }
}

resource "aws_api_gateway_integration" "read_integration" {
  rest_api_id = aws_api_gateway_rest_api.crud_api.id
  resource_id = aws_api_gateway_resource.item_resource.id
  http_method = aws_api_gateway_method.read_method.http_method

  type                    = "AWS"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${var.aws_region}:sqs:path/${data.aws_caller_identity.current.account_id}/${aws_sqs_queue.crud_queue.name}"
  credentials             = aws_iam_role.api_gateway_sqs_role.arn
  
  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }
  
  request_templates = {
    "application/json" = <<EOF
Action=SendMessage&MessageBody=$util.urlEncode({
  "operation": "get",
  "id": "$input.params('id')"
})
EOF
  }
}

resource "aws_api_gateway_integration" "update_integration" {
  rest_api_id = aws_api_gateway_rest_api.crud_api.id
  resource_id = aws_api_gateway_resource.item_resource.id
  http_method = aws_api_gateway_method.update_method.http_method

  type                    = "AWS"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${var.aws_region}:sqs:path/${data.aws_caller_identity.current.account_id}/${aws_sqs_queue.crud_queue.name}"
  credentials             = aws_iam_role.api_gateway_sqs_role.arn
  
  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }
  
  request_templates = {
    "application/json" = <<EOF
Action=SendMessage&MessageBody=$util.urlEncode({
  "operation": "update",
  "id": "$input.params('id')",
  "payload": $input.json('$')
})
EOF
  }
}

resource "aws_api_gateway_integration" "delete_integration" {
  rest_api_id = aws_api_gateway_rest_api.crud_api.id
  resource_id = aws_api_gateway_resource.item_resource.id
  http_method = aws_api_gateway_method.delete_method.http_method

  type                    = "AWS"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${var.aws_region}:sqs:path/${data.aws_caller_identity.current.account_id}/${aws_sqs_queue.crud_queue.name}"
  credentials             = aws_iam_role.api_gateway_sqs_role.arn
  
  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }
  
  request_templates = {
    "application/json" = <<EOF
Action=SendMessage&MessageBody=$util.urlEncode({
  "operation": "delete",
  "id": "$input.params('id')"
})
EOF
  }
}

# API Gateway integration responses
resource "aws_api_gateway_integration_response" "create_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.crud_api.id
  resource_id = aws_api_gateway_resource.items_resource.id
  http_method = aws_api_gateway_method.create_method.http_method
  status_code = aws_api_gateway_method_response.create_method_response.status_code
  
  response_templates = {
    "application/json" = <<EOF
{
  "message": "Item creation request received",
  "requestId": "$context.requestId"
}
EOF
  }
  
  depends_on = [aws_api_gateway_integration.create_integration]
}

resource "aws_api_gateway_method_response" "create_method_response" {
  rest_api_id = aws_api_gateway_rest_api.crud_api.id
  resource_id = aws_api_gateway_resource.items_resource.id
  http_method = aws_api_gateway_method.create_method.http_method
  status_code = "202"
  
  response_models = {
    "application/json" = "Empty"
  }
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_integration_response" "read_all_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.crud_api.id
  resource_id = aws_api_gateway_resource.items_resource.id
  http_method = aws_api_gateway_method.read_all_method.http_method
  status_code = aws_api_gateway_method_response.read_all_method_response.status_code
  
  response_templates = {
    "application/json" = <<EOF
{
  "message": "Read items request received",
  "requestId": "$context.requestId"
}
EOF
  }
  
  depends_on = [aws_api_gateway_integration.read_all_integration]
}

resource "aws_api_gateway_method_response" "read_all_method_response" {
  rest_api_id = aws_api_gateway_rest_api.crud_api.id
  resource_id = aws_api_gateway_resource.items_resource.id
  http_method = aws_api_gateway_method.read_all_method.http_method
  status_code = "202"
  
  response_models = {
    "application/json" = "Empty"
  }
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_integration_response" "read_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.crud_api.id
  resource_id = aws_api_gateway_resource.item_resource.id
  http_method = aws_api_gateway_method.read_method.http_method
  status_code = aws_api_gateway_method_response.read_method_response.status_code
  
  response_templates = {
    "application/json" = <<EOF
{
  "message": "Read item request received",
  "id": "$input.params('id')",
  "requestId": "$context.requestId"
}
EOF
  }
  
  depends_on = [aws_api_gateway_integration.read_integration]
}

resource "aws_api_gateway_method_response" "read_method_response" {
  rest_api_id = aws_api_gateway_rest_api.crud_api.id
  resource_id = aws_api_gateway_resource.item_resource.id
  http_method = aws_api_gateway_method.read_method.http_method
  status_code = "202"
  
  response_models = {
    "application/json" = "Empty"
  }
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_integration_response" "update_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.crud_api.id
  resource_id = aws_api_gateway_resource.item_resource.id
  http_method = aws_api_gateway_method.update_method.http_method
  status_code = aws_api_gateway_method_response.update_method_response.status_code
  
  response_templates = {
    "application/json" = <<EOF
{
  "message": "Update item request received",
  "id": "$input.params('id')",
  "requestId": "$context.requestId"
}
EOF
  }
  
  depends_on = [aws_api_gateway_integration.update_integration]
}

resource "aws_api_gateway_method_response" "update_method_response" {
  rest_api_id = aws_api_gateway_rest_api.crud_api.id
  resource_id = aws_api_gateway_resource.item_resource.id
  http_method = aws_api_gateway_method.update_method.http_method
  status_code = "202"
  
  response_models = {
    "application/json" = "Empty"
  }
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_integration_response" "delete_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.crud_api.id
  resource_id = aws_api_gateway_resource.item_resource.id
  http_method = aws_api_gateway_method.delete_method.http_method
  status_code = aws_api_gateway_method_response.delete_method_response.status_code
  
  response_templates = {
    "application/json" = <<EOF
{
  "message": "Delete item request received",
  "id": "$input.params('id')",
  "requestId": "$context.requestId"
}
EOF
  }
  
  depends_on = [aws_api_gateway_integration.delete_integration]
}

resource "aws_api_gateway_method_response" "delete_method_response" {
  rest_api_id = aws_api_gateway_rest_api.crud_api.id
  resource_id = aws_api_gateway_resource.item_resource.id
  http_method = aws_api_gateway_method.delete_method.http_method
  status_code = "202"
  
  response_models = {
    "application/json" = "Empty"
  }
  
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# IAM Role for API Gateway to send messages to SQS
resource "aws_iam_role" "api_gateway_sqs_role" {
  name = "${var.project_name}-api-gateway-sqs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-api-gateway-sqs-role"
    Environment = var.environment
  }
}

# IAM Policy for API Gateway to send messages to SQS
resource "aws_iam_policy" "api_gateway_sqs_policy" {
  name        = "${var.project_name}-api-gateway-sqs-policy"
  description = "IAM policy for API Gateway to send messages to SQS"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = [
          aws_sqs_queue.crud_queue.arn
        ]
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-api-gateway-sqs-policy"
    Environment = var.environment
  }
}

# Attach SQS policy to API Gateway role
resource "aws_iam_role_policy_attachment" "api_gateway_sqs_policy_attachment" {
  role       = aws_iam_role.api_gateway_sqs_role.name
  policy_arn = aws_iam_policy.api_gateway_sqs_policy.arn
}
