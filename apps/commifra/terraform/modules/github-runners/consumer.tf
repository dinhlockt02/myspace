resource "aws_cloudwatch_log_group" "consumer" {
  name              = "/aws/lambda/commifra-github-runner-consumer"
  retention_in_days = 14

  tags = merge(local.common_tags, {
    Module = "github-runners"
  })
}

resource "aws_lambda_function" "consumer" {
  function_name    = "commifra-github-runner-consumer"
  role             = aws_iam_role.consumer_lambda.arn
  handler          = "consumer_handler.handler"
  runtime          = "nodejs22.x"
  architectures    = ["x86_64"]
  timeout          = var.sqs_visibility_timeout
  memory_size      = 128
  filename         = data.archive_file.consumer_lambda.output_path
  source_code_hash = data.archive_file.consumer_lambda.output_base64sha256

  environment {
    variables = {
      GITHUB_OWNER       = var.github_owner
      GITHUB_REPO        = var.github_repo
      GITHUB_TOKEN_SSM   = var.github_token_ssm
      LAUNCH_TEMPLATE_ID = aws_launch_template.runner.id
      SUBNET_IDS         = join(",", var.subnet_ids)
      MAX_RUNNERS        = var.max_count
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.consumer,
    aws_iam_role_policy.consumer_lambda
  ]

  tags = merge(local.common_tags, {
    Module = "github-runners"
  })
}

resource "aws_lambda_event_source_mapping" "sqs" {
  event_source_arn = aws_sqs_queue.jobs.arn
  function_name    = aws_lambda_function.consumer.function_name
  batch_size       = var.sqs_batch_size
  enabled          = true
}
