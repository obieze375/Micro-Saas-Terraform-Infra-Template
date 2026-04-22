locals {
  api_lambda_name    = "${local.name_prefix}-api"
  worker_lambda_name = "${local.name_prefix}-worker"
  ses_identity_arn = var.ses_identity == null ? null : format(
    "arn:%s:ses:%s:%s:identity/%s",
    data.aws_partition.current.partition,
    data.aws_region.current.name,
    data.aws_caller_identity.current.account_id,
    var.ses_identity
  )
}

data "archive_file" "api_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/api"
  output_path = "${path.module}/.api-lambda.zip"
}

data "archive_file" "worker_lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/worker"
  output_path = "${path.module}/.worker-lambda.zip"
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "api_lambda" {
  name               = "${local.name_prefix}-api-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = local.common_tags
}

resource "aws_iam_role" "worker_lambda" {
  name               = "${local.name_prefix}-worker-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "api_basic_execution" {
  role       = aws_iam_role.api_lambda.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "worker_basic_execution" {
  role       = aws_iam_role.worker_lambda.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "worker_sqs_execution" {
  role       = aws_iam_role.worker_lambda.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
}

resource "aws_iam_role_policy_attachment" "api_additional_managed_policies" {
  for_each   = toset(var.lambda_additional_policy_arns)
  role       = aws_iam_role.api_lambda.name
  policy_arn = each.value
}

resource "aws_iam_role_policy_attachment" "worker_additional_managed_policies" {
  for_each   = toset(var.lambda_additional_policy_arns)
  role       = aws_iam_role.worker_lambda.name
  policy_arn = each.value
}

data "aws_iam_policy_document" "api_access" {
  statement {
    sid = "DynamoWorkItemsReadWrite"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:PutItem",
      "dynamodb:UpdateItem",
      "dynamodb:Query"
    ]
    resources = [
      aws_dynamodb_table.work_items.arn,
      "${aws_dynamodb_table.work_items.arn}/index/*"
    ]
  }

  statement {
    sid = "QueueSendTasks"
    actions = [
      "sqs:GetQueueAttributes",
      "sqs:SendMessage"
    ]
    resources = [aws_sqs_queue.work_queue.arn]
  }

  statement {
    sid = "AssetsReadWrite"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject"
    ]
    resources = ["${aws_s3_bucket.app_data.arn}/*"]
  }

  statement {
    sid = "AssetsList"
    actions = [
      "s3:ListBucket"
    ]
    resources = [aws_s3_bucket.app_data.arn]
  }

  dynamic "statement" {
    for_each = toset(var.lambda_integration_secret_arns)
    content {
      actions = [
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetSecretValue"
      ]
      resources = [statement.value]
    }
  }

  dynamic "statement" {
    for_each = toset(var.lambda_integration_parameter_arns)
    content {
      actions = [
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:GetParameterHistory"
      ]
      resources = [statement.value]
    }
  }

  dynamic "statement" {
    for_each = toset(var.lambda_integration_kms_key_arns)
    content {
      actions = ["kms:Decrypt"]
      resources = [statement.value]
    }
  }

  dynamic "statement" {
    for_each = toset(var.lambda_integration_assume_role_arns)
    content {
      actions   = ["sts:AssumeRole"]
      resources = [statement.value]
    }
  }
}

resource "aws_iam_role_policy" "api_access" {
  name   = "${local.name_prefix}-api-access"
  role   = aws_iam_role.api_lambda.id
  policy = data.aws_iam_policy_document.api_access.json
}

data "aws_iam_policy_document" "worker_access" {
  statement {
    sid = "DynamoWorkItemsUpdate"
    actions = [
      "dynamodb:GetItem",
      "dynamodb:UpdateItem",
      "dynamodb:PutItem",
      "dynamodb:Query"
    ]
    resources = [
      aws_dynamodb_table.work_items.arn,
      "${aws_dynamodb_table.work_items.arn}/index/*"
    ]
  }

  statement {
    sid = "QueueConsumeTasks"
    actions = [
      "sqs:ChangeMessageVisibility",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ReceiveMessage"
    ]
    resources = [aws_sqs_queue.work_queue.arn]
  }

  dynamic "statement" {
    for_each = local.ses_identity_arn == null ? [] : [local.ses_identity_arn]
    content {
      sid = "SendEmail"
      actions = [
        "ses:SendEmail",
        "ses:SendRawEmail"
      ]
      resources = [statement.value]
    }
  }

  dynamic "statement" {
    for_each = toset(var.lambda_integration_secret_arns)
    content {
      actions = [
        "secretsmanager:DescribeSecret",
        "secretsmanager:GetSecretValue"
      ]
      resources = [statement.value]
    }
  }

  dynamic "statement" {
    for_each = toset(var.lambda_integration_parameter_arns)
    content {
      actions = [
        "ssm:GetParameter",
        "ssm:GetParameters",
        "ssm:GetParameterHistory"
      ]
      resources = [statement.value]
    }
  }

  dynamic "statement" {
    for_each = toset(var.lambda_integration_kms_key_arns)
    content {
      actions = ["kms:Decrypt"]
      resources = [statement.value]
    }
  }

  dynamic "statement" {
    for_each = toset(var.lambda_integration_assume_role_arns)
    content {
      actions   = ["sts:AssumeRole"]
      resources = [statement.value]
    }
  }
}

resource "aws_iam_role_policy" "worker_access" {
  name   = "${local.name_prefix}-worker-access"
  role   = aws_iam_role.worker_lambda.id
  policy = data.aws_iam_policy_document.worker_access.json
}

resource "aws_cloudwatch_log_group" "api_lambda" {
  name              = "/aws/lambda/${local.api_lambda_name}"
  retention_in_days = var.lambda_log_retention_days
  tags              = local.common_tags
}

resource "aws_cloudwatch_log_group" "worker_lambda" {
  name              = "/aws/lambda/${local.worker_lambda_name}"
  retention_in_days = var.lambda_log_retention_days
  tags              = local.common_tags
}

resource "aws_lambda_function" "api" {
  function_name = local.api_lambda_name
  role          = aws_iam_role.api_lambda.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  architectures = ["arm64"]
  timeout       = var.api_timeout
  memory_size   = var.api_memory_size

  filename         = data.archive_file.api_lambda_zip.output_path
  source_code_hash = data.archive_file.api_lambda_zip.output_base64sha256

  environment {
    variables = {
      MAIN_TABLE_NAME       = aws_dynamodb_table.work_items.name
      TASK_QUEUE_URL        = aws_sqs_queue.work_queue.id
      APP_DATA_BUCKET       = aws_s3_bucket.app_data.id
      COGNITO_USER_POOL_ID  = var.enable_cognito ? aws_cognito_user_pool.auth[0].id : ""
      COGNITO_APP_CLIENT_ID = var.enable_cognito ? aws_cognito_user_pool_client.spa[0].id : ""
    }
  }

  depends_on = [
    aws_iam_role_policy.api_access,
    aws_iam_role_policy_attachment.api_basic_execution,
    aws_cloudwatch_log_group.api_lambda
  ]

  tags = local.common_tags
}

resource "aws_lambda_function" "worker" {
  function_name = local.worker_lambda_name
  role          = aws_iam_role.worker_lambda.arn
  handler       = "index.handler"
  runtime       = "nodejs20.x"
  architectures = ["arm64"]
  timeout       = var.worker_timeout
  memory_size   = var.worker_memory_size

  filename         = data.archive_file.worker_lambda_zip.output_path
  source_code_hash = data.archive_file.worker_lambda_zip.output_base64sha256

  environment {
    variables = {
      MAIN_TABLE_NAME           = aws_dynamodb_table.work_items.name
      TASK_QUEUE_URL            = aws_sqs_queue.work_queue.id
      SES_IDENTITY              = var.ses_identity == null ? "" : var.ses_identity
      SES_FROM_EMAIL            = var.notifications_sender_email == null ? "" : var.notifications_sender_email
      TEMPLATE_RESULT_MESSAGE   = var.template_result_message
      WORKER_BATCH_LIMIT        = tostring(var.worker_batch_limit)
      DEFAULT_WORKER_CONCURRENCY = tostring(var.default_worker_concurrency)
    }
  }

  depends_on = [
    aws_iam_role_policy.worker_access,
    aws_iam_role_policy_attachment.worker_basic_execution,
    aws_iam_role_policy_attachment.worker_sqs_execution,
    aws_cloudwatch_log_group.worker_lambda
  ]

  tags = local.common_tags
}

resource "aws_lambda_event_source_mapping" "worker_tasks" {
  event_source_arn                   = aws_sqs_queue.work_queue.arn
  function_name                      = aws_lambda_function.worker.arn
  batch_size                         = var.worker_event_batch_size
  maximum_batching_window_in_seconds = 5
  enabled                            = true
}

resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowInvokeFromApiGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*"
}
