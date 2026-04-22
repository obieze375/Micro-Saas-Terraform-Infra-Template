output "frontend_bucket_name" {
  description = "S3 bucket for static frontend assets."
  value       = aws_s3_bucket.frontend.id
}

output "app_data_bucket_name" {
  description = "S3 bucket used by Lambda workloads."
  value       = aws_s3_bucket.app_data.id
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID."
  value       = aws_cloudfront_distribution.frontend.id
}

output "frontend_url" {
  description = "Primary frontend URL."
  value = length(var.domain_aliases) > 0 ? format(
    "https://%s",
    var.domain_aliases[0]
  ) : var.domain_name == null ? format(
    "https://%s",
    aws_cloudfront_distribution.frontend.domain_name
  ) : format(
    "https://%s",
    var.domain_name
  )
}

output "api_endpoint" {
  description = "HTTP API endpoint URL."
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "dynamodb_table_name" {
  description = "DynamoDB table used by Lambda workflows."
  value       = aws_dynamodb_table.work_items.name
}

output "work_queue_url" {
  description = "SQS queue URL for worker messages."
  value       = aws_sqs_queue.work_queue.id
}

output "api_lambda_name" {
  description = "API handler Lambda function name."
  value       = aws_lambda_function.api.function_name
}

output "api_lambda_role_arn" {
  description = "API Lambda execution role ARN."
  value       = aws_iam_role.api_lambda.arn
}

output "worker_lambda_name" {
  description = "Queue worker Lambda function name."
  value       = aws_lambda_function.worker.function_name
}

output "worker_lambda_role_arn" {
  description = "Worker Lambda execution role ARN."
  value       = aws_iam_role.worker_lambda.arn
}

output "cognito_user_pool_id" {
  description = "Cognito user pool ID (if enabled)."
  value       = var.enable_cognito ? aws_cognito_user_pool.auth[0].id : null
}

output "cognito_user_pool_client_id" {
  description = "Cognito app client ID (if enabled)."
  value       = var.enable_cognito ? aws_cognito_user_pool_client.spa[0].id : null
}
