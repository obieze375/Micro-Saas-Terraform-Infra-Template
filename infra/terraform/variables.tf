variable "aws_region" {
  description = "Primary AWS region for the stack."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used in resource naming."
  type        = string
  default     = "serverless-template"
}

variable "environment" {
  description = "Environment suffix (e.g. dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "domain_name" {
  description = "Optional custom domain for CloudFront (e.g. app.example.com)."
  type        = string
  default     = null
  nullable    = true
}

variable "domain_aliases" {
  description = "Optional additional CloudFront custom domains (for example, www.app.example.com)."
  type        = list(string)
  default     = []
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID for the custom domain."
  type        = string
  default     = null
  nullable    = true
}

variable "cors_allowed_origins" {
  description = "CORS allowed origins for API Gateway."
  type        = list(string)
  default     = ["*"]
}

variable "cloudfront_price_class" {
  description = "CloudFront price class."
  type        = string
  default     = "PriceClass_100"
}

variable "api_log_retention_days" {
  description = "CloudWatch log retention for API Gateway stage logs."
  type        = number
  default     = 30
}

variable "lambda_log_retention_days" {
  description = "CloudWatch log retention for Lambda functions."
  type        = number
  default     = 30
}

variable "api_memory_size" {
  description = "Memory size for API Lambda."
  type        = number
  default     = 256
}

variable "api_timeout" {
  description = "Timeout (seconds) for API Lambda."
  type        = number
  default     = 10
}

variable "worker_memory_size" {
  description = "Memory size for worker Lambda."
  type        = number
  default     = 256
}

variable "worker_timeout" {
  description = "Timeout (seconds) for worker Lambda."
  type        = number
  default     = 60
}

variable "queue_visibility_timeout_seconds" {
  description = "Visibility timeout for worker queue."
  type        = number
  default     = 180
}

variable "queue_message_retention_seconds" {
  description = "Retention period for worker queue messages."
  type        = number
  default     = 1209600

  validation {
    condition     = var.queue_message_retention_seconds >= 60 && var.queue_message_retention_seconds <= 1209600
    error_message = "queue_message_retention_seconds must be between 60 and 1209600 seconds."
  }
}

variable "api_throttling_burst_limit" {
  description = "API Gateway default route burst throttling limit."
  type        = number
  default     = 50
}

variable "api_throttling_rate_limit" {
  description = "API Gateway default route steady-state throttling rate limit."
  type        = number
  default     = 100
}

variable "worker_batch_limit" {
  description = "Sample worker batch size metadata passed to the worker Lambda."
  type        = number
  default     = 25
}

variable "default_worker_concurrency" {
  description = "Sample worker concurrency metadata passed to the worker Lambda."
  type        = number
  default     = 2
}

variable "worker_event_batch_size" {
  description = "SQS event source mapping batch size for the worker Lambda."
  type        = number
  default     = 5
}

variable "worker_result_ttl_days" {
  description = "Number of days before worker results expire via DynamoDB TTL."
  type        = number
  default     = 14
}

variable "ses_identity" {
  description = "Optional SES identity (domain/email) for worker notifications."
  type        = string
  default     = null
  nullable    = true
}

variable "notifications_sender_email" {
  description = "Optional sender email for sample worker notifications."
  type        = string
  default     = null
  nullable    = true
}

variable "template_result_message" {
  description = "Message written by the sample worker Lambda when processing completes."
  type        = string
  default     = "Task processed by template worker."
}

variable "lambda_integration_secret_arns" {
  description = "Optional Secrets Manager secret ARNs that Lambdas can read."
  type        = list(string)
  default     = []
}

variable "lambda_integration_parameter_arns" {
  description = "Optional SSM Parameter Store ARNs that Lambdas can read for integrations."
  type        = list(string)
  default     = []
}

variable "lambda_integration_kms_key_arns" {
  description = "Optional KMS key ARNs Lambdas can use to decrypt integration values."
  type        = list(string)
  default     = []
}

variable "lambda_integration_assume_role_arns" {
  description = "Optional IAM role ARNs Lambdas can assume for delegated access."
  type        = list(string)
  default     = []
}

variable "lambda_additional_policy_arns" {
  description = "Optional managed policy ARNs to attach to both Lambda execution roles."
  type        = list(string)
  default     = []
}

variable "enable_cognito" {
  description = "Whether to create Cognito resources and enable JWT auth on task routes."
  type        = bool
  default     = false
}

variable "frontend_bucket_force_destroy" {
  description = "Allow destroying frontend bucket with objects."
  type        = bool
  default     = false
}

variable "assets_bucket_force_destroy" {
  description = "Allow destroying app data bucket with objects."
  type        = bool
  default     = false
}

variable "assets_cors_allowed_origins" {
  description = "Allowed origins for app data S3 bucket CORS."
  type        = list(string)
  default     = ["*"]
}

variable "assets_cors_allowed_headers" {
  description = "Allowed headers for app data S3 bucket CORS."
  type        = list(string)
  default     = ["*"]
}

variable "assets_cors_allowed_methods" {
  description = "Allowed methods for app data S3 bucket CORS."
  type        = list(string)
  default     = ["GET", "PUT", "POST", "HEAD"]
}

variable "assets_cors_expose_headers" {
  description = "Exposed headers for app data S3 bucket CORS."
  type        = list(string)
  default     = ["ETag"]
}

variable "tags" {
  description = "Additional tags to apply to all resources."
  type        = map(string)
  default     = {}
}
