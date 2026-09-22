resource "aws_ssm_parameter" "github_token" {
  name  = var.github_token_ssm
  type  = "SecureString"
  value = var.github_pat

  tags = merge(local.common_tags, {
    Module = "github-runners"
  })

  lifecycle {
    ignore_changes = [value]
  }
}

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

data "archive_file" "webhook_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/dist/webhook_handler.mjs"
  output_path = "${path.module}/webhook_lambda.zip"
}

data "archive_file" "consumer_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/dist/consumer_handler.mjs"
  output_path = "${path.module}/consumer_lambda.zip"
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
  role             = aws_iam_role.webhook_lambda.arn
  handler          = "webhook_handler.handler"
  runtime          = "nodejs22.x"
  architectures    = ["x86_64"]
  timeout          = 30
  memory_size      = 128
  filename         = data.archive_file.webhook_lambda.output_path
  source_code_hash = data.archive_file.webhook_lambda.output_base64sha256

  environment {
    variables = {
      GITHUB_OWNER       = var.github_owner
      GITHUB_REPO        = var.github_repo
      WEBHOOK_SECRET_SSM = var.webhook_secret_ssm
      SQS_QUEUE_URL      = aws_sqs_queue.jobs.url
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy.webhook_lambda
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

resource "aws_lambda_permission" "function_trigger" {
  statement_id  = "FunctionURLInvokeAllowPublicAccess"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.webhook.function_name
  principal     = "*"
}