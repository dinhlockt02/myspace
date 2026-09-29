# trigger
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
# DynamoDB Table
# -----------------------------------------------------------------------------
resource "aws_dynamodb_table" "ideas" {
  name         = "IdeaCollector_Ideas"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
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

data "aws_iam_policy_document" "dynamodb_write" {
  statement {
    actions = [
      "dynamodb:PutItem",
    ]
    resources = [aws_dynamodb_table.ideas.arn]
  }
}

resource "aws_iam_policy" "dynamodb_write" {
  name   = "IdeaCollector_DynamoDBWrite"
  policy = data.aws_iam_policy_document.dynamodb_write.json
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.dynamodb_write.arn
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
      TABLE_NAME = aws_dynamodb_table.ideas.name
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

resource "aws_apigatewayv2_integration" "lambda" {
  api_id           = aws_apigatewayv2_api.ingestion.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.ingestion.invoke_arn
}

resource "aws_apigatewayv2_route" "post_ideas" {
  api_id    = aws_apigatewayv2_api.ingestion.id
  route_key = "POST /api/ideas"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.ingestion.id
  name        = "$default"
  auto_deploy = true
}
