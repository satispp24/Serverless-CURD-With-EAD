# Dead Letter Queue for Lambda functions
resource "aws_sqs_queue" "dlq" {
  name                      = "${var.project_name}-dlq"
  message_retention_seconds = 1209600 # 14 days

  tags = {
    Name        = "${var.project_name}-dlq"
    Environment = var.environment
    Service     = "crud-api"
  }
}

# SQS Queue Policy for Lambda DLQ
resource "aws_sqs_queue_policy" "dlq_policy" {
  queue_url = aws_sqs_queue.dlq.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.dlq.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

# Single CRUD Operations Queue
resource "aws_sqs_queue" "crud_queue" {
  name                      = "${var.project_name}-crud-queue"
  message_retention_seconds = 86400 # 1 day
  visibility_timeout_seconds = 60   # Match Lambda timeout
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name        = "${var.project_name}-crud-queue"
    Environment = var.environment
    Service     = "crud-api"
  }
}

# SQS Queue Policy for API Gateway
resource "aws_sqs_queue_policy" "crud_queue_policy" {
  queue_url = aws_sqs_queue.crud_queue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.crud_queue.arn
      }
    ]
  })
}
