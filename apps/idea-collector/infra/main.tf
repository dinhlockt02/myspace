# trigger!!!!!
locals {
  fqdn = "${var.subdomain}.${var.domain_name}"
}

data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

# -----------------------------------------------------------------------------
# ACM Certificate (Must be in us-east-1 for CloudFront)
# -----------------------------------------------------------------------------
resource "aws_acm_certificate" "frontend" {
  provider          = aws.us_east_1
  domain_name       = local.fqdn
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.frontend.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
}

resource "aws_acm_certificate_validation" "frontend" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.frontend.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

module "frontend" {
  source = "./modules/frontend"
  project_name                   = var.project_name
  bucket_name                    = var.bucket_name
  distribution_enabled           = var.distribution_enabled
  is_ipv6_enabled                = var.is_ipv6_enabled
  default_root_object            = var.default_root_object
  distribution_comment           = var.distribution_comment
  price_class                    = var.price_class
  aliases                        = [local.fqdn]
  allowed_methods                = var.allowed_methods
  cached_methods                 = var.cached_methods
  viewer_protocol_policy         = var.viewer_protocol_policy
  custom_error_responses         = var.custom_error_responses
  geo_restriction_type           = var.geo_restriction_type
  geo_restriction_locations      = var.geo_restriction_locations
  cloudfront_default_certificate = false
  acm_certificate_arn            = aws_acm_certificate_validation.frontend.certificate_arn
  minimum_protocol_version       = var.minimum_protocol_version
  tags                           = var.tags
  api_gateway_domain_name        = trimprefix(aws_apigatewayv2_api.ingestion.api_endpoint, "https://")
}

# -----------------------------------------------------------------------------
# Route53 Alias Record for CloudFront
# -----------------------------------------------------------------------------
resource "aws_route53_record" "frontend_alias" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = local.fqdn
  type    = "A"

  alias {
    name                   = module.frontend.cloudfront_domain_name
    zone_id                = "Z2FDTNDATAQYW2" # Hardcoded Zone ID for all CloudFront distributions
    evaluate_target_health = false
  }
}

# -----------------------------------------------------------------------------
# DynamoDB Tables
# -----------------------------------------------------------------------------
resource "aws_dynamodb_table" "ideas" {
  name         = "IdeaCollector_Ideas"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "server_timestamp"
    type = "N"
  }

  global_secondary_index {
    name            = "UserIdeasIndex"
    hash_key        = "user_id"
    range_key       = "server_timestamp"
    projection_type = "ALL"
  }
}

resource "aws_dynamodb_table" "users" {
  name         = "IdeaCollector_Users"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "email"

  attribute {
    name = "email"
    type = "S"
  }
}

resource "aws_dynamodb_table" "sessions" {
  name         = "IdeaCollector_Sessions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "session_id"

  attribute {
    name = "session_id"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }
}

# -----------------------------------------------------------------------------
# Lambda Function Package
# -----------------------------------------------------------------------------
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../backend/bootstrap"
  output_path = "${path.module}/../backend/function.zip"
}

# -----------------------------------------------------------------------------
# IAM Role for Lambda
# -----------------------------------------------------------------------------
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "IdeaCollector_LambdaExecRole"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "dynamodb_access" {
  statement {
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:UpdateItem",
      "dynamodb:DeleteItem",
      "dynamodb:Query",
      "dynamodb:Scan",
    ]
    resources = [
      aws_dynamodb_table.ideas.arn,
      "${aws_dynamodb_table.ideas.arn}/index/*",
      aws_dynamodb_table.users.arn,
      aws_dynamodb_table.sessions.arn,
    ]
  }
}

resource "aws_iam_policy" "dynamodb_access" {
  name   = "IdeaCollector_DynamoDBAccess"
  policy = data.aws_iam_policy_document.dynamodb_access.json
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.dynamodb_access.arn
}

# -----------------------------------------------------------------------------
# AWS Cognito User Pool & Federation
# -----------------------------------------------------------------------------
resource "aws_cognito_user_pool" "main" {
  name                     = "${var.project_name}-user-pool"
  auto_verified_attributes = ["email"]
  username_attributes      = ["email"]

  schema {
    attribute_data_type = "String"
    name                = "email"
    required            = true
    mutable             = true
  }

  schema {
    attribute_data_type = "String"
    name                = "name"
    required            = false
    mutable             = true
  }

  # Cognito does not allow schema attributes to be modified or removed after
  # creation, and AWS reports extra defaults that show up as drift.
  lifecycle {
    ignore_changes = [schema]
  }
}

resource "aws_cognito_identity_provider" "google" {
  user_pool_id  = aws_cognito_user_pool.main.id
  provider_name = "Google"
  provider_type = "Google"

  # Cognito fills in Google's endpoints itself and returns them on every read. Without these
  # values here, every plan proposes removing them (a perpetual diff), so they are stated
  # explicitly and match what AWS reports. Client id, secret and scopes stay tracked, unlike
  # with ignore_changes on the whole map.
  provider_details = {
    client_id                     = var.google_client_id
    client_secret                 = var.google_client_secret
    authorize_scopes              = "openid email profile"
    attributes_url                = "https://people.googleapis.com/v1/people/me?personFields="
    attributes_url_add_attributes = "true"
    authorize_url                 = "https://accounts.google.com/o/oauth2/v2/auth"
    oidc_issuer                   = "https://accounts.google.com"
    token_request_method          = "POST"
    token_url                     = "https://www.googleapis.com/oauth2/v4/token"
  }

  attribute_mapping = {
    email    = "email"
    name     = "name"
    username = "sub"
  }
}

resource "aws_cognito_user_pool_domain" "main" {
  domain       = var.cognito_domain_prefix
  user_pool_id = aws_cognito_user_pool.main.id
}

resource "aws_cognito_user_pool_client" "client" {
  name         = "${var.project_name}-spa-client"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret = false
  explicit_auth_flows = [
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_SRP_AUTH"
  ]

  supported_identity_providers = ["COGNITO", "Google"]

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["openid", "email", "profile"]

  callback_urls = [
    "https://${local.fqdn}",
    "http://localhost:5173"
  ]

  logout_urls = [
    "https://${local.fqdn}",
    "http://localhost:5173"
  ]

  depends_on = [aws_cognito_identity_provider.google]
}

# -----------------------------------------------------------------------------
# Lambda Function
# -----------------------------------------------------------------------------
resource "aws_lambda_function" "ingestion" {
  function_name    = "IdeaCollector_Ingestion"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  role             = aws_iam_role.lambda_exec.arn
  handler          = "bootstrap"
  runtime          = "provided.al2023"
  architectures    = ["x86_64"]

  environment {
    variables = {
      TABLE_NAME            = aws_dynamodb_table.ideas.name
      COGNITO_USER_POOL_ID  = aws_cognito_user_pool.main.id
      COGNITO_APP_CLIENT_ID = aws_cognito_user_pool_client.client.id
      GOOGLE_CLIENT_ID      = var.google_client_id
    }
  }
}

# -----------------------------------------------------------------------------
# HTTP API Gateway (v2)
# -----------------------------------------------------------------------------
resource "aws_apigatewayv2_api" "ingestion" {
  name          = "IdeaCollector_IngestionAPI"
  protocol_type = "HTTP"
  target        = aws_lambda_function.ingestion.arn
}

resource "aws_lambda_permission" "apigw" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingestion.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.ingestion.execution_arn}/*/*"
}

resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.ingestion.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "CognitoAuthorizer"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.client.id]
    issuer   = "https://${aws_cognito_user_pool.main.endpoint}"
  }
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id           = aws_apigatewayv2_api.ingestion.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.ingestion.invoke_arn
}

resource "aws_apigatewayv2_route" "post_ideas" {
  api_id             = aws_apigatewayv2_api.ingestion.id
  route_key          = "POST /api/ideas"
  target             = "integrations/${aws_apigatewayv2_integration.lambda.id}"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
  authorization_type = "JWT"
}

resource "aws_apigatewayv2_route" "get_ideas" {
  api_id             = aws_apigatewayv2_api.ingestion.id
  route_key          = "GET /api/ideas"
  target             = "integrations/${aws_apigatewayv2_integration.lambda.id}"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
  authorization_type = "JWT"
}

resource "aws_apigatewayv2_route" "get_auth_me" {
  api_id             = aws_apigatewayv2_api.ingestion.id
  route_key          = "GET /api/auth/me"
  target             = "integrations/${aws_apigatewayv2_integration.lambda.id}"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id
  authorization_type = "JWT"
}


