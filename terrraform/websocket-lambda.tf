# Notification SQS Queue
resource "aws_sqs_queue" "notification_queue" {
  name                      = "${var.project_name}-notification-queue"
  message_retention_seconds = 86400 # 1 day
  visibility_timeout_seconds = 60   # Match Lambda timeout
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name        = "${var.project_name}-notification-queue"
    Environment = var.environment
    Service     = "crud-api"
  }
}

# Notification Lambda Function
data "archive_file" "notification_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda-functions/notification"
  output_path = "${path.module}/lambda-functions/notification.zip"
}

resource "aws_lambda_function" "notification_lambda" {
  filename         = data.archive_file.notification_lambda_zip.output_path
  function_name    = "${var.project_name}-notification"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.notification_lambda_zip.output_base64sha256
  runtime          = "python3.12"
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size

  environment {
    variables = {
      CONNECTIONS_TABLE_NAME  = aws_dynamodb_table.connections_table.name
      WEBSOCKET_API_ENDPOINT  = "${aws_apigatewayv2_api.websocket_api.api_endpoint}/${aws_apigatewayv2_stage.websocket_stage.name}"
      LOG_LEVEL              = var.log_level
    }
  }

  tags = {
    Name        = "${var.project_name}-notification-lambda"
    Environment = var.environment
    Service     = "crud-api"
  }
}

# SQS Event Source Mapping for Notification Lambda
resource "aws_lambda_event_source_mapping" "notification_event_source" {
  event_source_arn = aws_sqs_queue.notification_queue.arn
  function_name    = aws_lambda_function.notification_lambda.arn
  batch_size       = 1
  enabled          = true
}

# CloudWatch Log Group for Notification Lambda
resource "aws_cloudwatch_log_group" "notification_lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-notification"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.enable_log_encryption ? aws_kms_key.logs[0].arn : null

  tags = {
    Name        = "${var.project_name}-notification-logs"
    Environment = var.environment
    Service     = "crud-api"
  }
}

# WebSocket Lambda Functions
data "archive_file" "websocket_connect_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda-functions/websocket-connect"
  output_path = "${path.module}/lambda-functions/websocket-connect.zip"
}

data "archive_file" "websocket_disconnect_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda-functions/websocket-disconnect"
  output_path = "${path.module}/lambda-functions/websocket-disconnect.zip"
}

data "archive_file" "websocket_default_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/lambda-functions/websocket-default"
  output_path = "${path.module}/lambda-functions/websocket-default.zip"
}

resource "aws_lambda_function" "websocket_connect_lambda" {
  filename         = data.archive_file.websocket_connect_lambda_zip.output_path
  function_name    = "${var.project_name}-websocket-connect"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.websocket_connect_lambda_zip.output_base64sha256
  runtime          = "python3.12"
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size

  environment {
    variables = {
      CONNECTIONS_TABLE_NAME = aws_dynamodb_table.connections_table.name
      LOG_LEVEL             = var.log_level
    }
  }

  tags = {
    Name        = "${var.project_name}-websocket-connect-lambda"
    Environment = var.environment
    Service     = "crud-api"
  }
}

resource "aws_lambda_function" "websocket_disconnect_lambda" {
  filename         = data.archive_file.websocket_disconnect_lambda_zip.output_path
  function_name    = "${var.project_name}-websocket-disconnect"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.websocket_disconnect_lambda_zip.output_base64sha256
  runtime          = "python3.12"
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size

  environment {
    variables = {
      CONNECTIONS_TABLE_NAME = aws_dynamodb_table.connections_table.name
      LOG_LEVEL             = var.log_level
    }
  }

  tags = {
    Name        = "${var.project_name}-websocket-disconnect-lambda"
    Environment = var.environment
    Service     = "crud-api"
  }
}

resource "aws_lambda_function" "websocket_default_lambda" {
  filename         = data.archive_file.websocket_default_lambda_zip.output_path
  function_name    = "${var.project_name}-websocket-default"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = data.archive_file.websocket_default_lambda_zip.output_base64sha256
  runtime          = "python3.12"
  timeout          = var.lambda_timeout
  memory_size      = var.lambda_memory_size

  environment {
    variables = {
      CONNECTIONS_TABLE_NAME = aws_dynamodb_table.connections_table.name
      LOG_LEVEL             = var.log_level
    }
  }

  tags = {
    Name        = "${var.project_name}-websocket-default-lambda"
    Environment = var.environment
    Service     = "crud-api"
  }
}

# CloudWatch Log Groups for WebSocket Lambda functions
resource "aws_cloudwatch_log_group" "websocket_connect_lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-websocket-connect"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.enable_log_encryption ? aws_kms_key.logs[0].arn : null

  tags = {
    Name        = "${var.project_name}-websocket-connect-logs"
    Environment = var.environment
    Service     = "crud-api"
  }
}

resource "aws_cloudwatch_log_group" "websocket_disconnect_lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-websocket-disconnect"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.enable_log_encryption ? aws_kms_key.logs[0].arn : null

  tags = {
    Name        = "${var.project_name}-websocket-disconnect-logs"
    Environment = var.environment
    Service     = "crud-api"
  }
}

resource "aws_cloudwatch_log_group" "websocket_default_lambda_logs" {
  name              = "/aws/lambda/${var.project_name}-websocket-default"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.enable_log_encryption ? aws_kms_key.logs[0].arn : null

  tags = {
    Name        = "${var.project_name}-websocket-default-logs"
    Environment = var.environment
    Service     = "crud-api"
  }
}