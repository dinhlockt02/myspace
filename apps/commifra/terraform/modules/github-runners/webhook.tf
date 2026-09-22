resource "random_password" "webhook_secret" {
  length  = 32
  special = false
}

resource "aws_ssm_parameter" "webhook_secret" {
  name  = var.webhook_secret_ssm
  type  = "SecureString"
  value = random_password.webhook_secret.result
  tags = merge(local.common_tags, {
    Module = "github-runners"
  })

  lifecycle {
    ignore_changes = [value]
  }
}

data "archive_file" "lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/commifra-github-runner-webhook"
  retention_in_days = 14
  tags = merge(local.common_tags, {
    Module = "github-runners"
  })
}

resource "aws_lambda_function" "webhook" {
  function_name    = "commifra-github-runner-webhook"
  role             = aws_iam_role.lambda.arn
  handler          = "index.handler"
  runtime          = "python3.12"
  architectures    = ["arm64"]
  timeout          = 30
  memory_size      = 128
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  environment {
    variables = {
      GITHUB_OWNER       = var.github_owner
      GITHUB_REPO        = var.github_repo
      WEBHOOK_SECRET_SSM = var.webhook_secret_ssm
      GITHUB_TOKEN_SSM   = var.github_token_ssm
      LAUNCH_TEMPLATE_ID = aws_launch_template.runner.id
      SUBNET_IDS         = join(",", var.subnet_ids)
      REGION             = data.aws_caller_identity.current.account_id
      MAX_RUNNERS        = var.max_count
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy.lambda
  ]

  tags = merge(local.common_tags, {
    Module = "github-runners"
  })
}

resource "aws_lambda_function_url" "webhook" {
  function_name      = aws_lambda_function.webhook.function_name
  authorization_type = "NONE"
}

resource "aws_lambda_permission" "function_url" {
  statement_id           = "AllowFunctionURLInvoke"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.webhook.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}
