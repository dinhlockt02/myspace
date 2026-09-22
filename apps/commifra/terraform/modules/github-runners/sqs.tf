resource "aws_sqs_queue" "jobs" {
  name                       = "commifra-github-runner-jobs"
  visibility_timeout_seconds = var.sqs_visibility_timeout
  message_retention_seconds  = 3600
  receive_wait_time_seconds  = 20

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.jobs_dlq.arn
    maxReceiveCount     = var.sqs_max_retries
  })

  tags = merge(local.common_tags, {
    Module = "github-runners"
  })
}

resource "aws_sqs_queue" "jobs_dlq" {
  name                      = "commifra-github-runner-jobs-dlq"
  message_retention_seconds = 1209600

  tags = merge(local.common_tags, {
    Module = "github-runners"
  })
}

resource "aws_cloudwatch_metric_alarm" "dlq" {
  alarm_name          = "commifra-github-runner-dlq-messages"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Alert when DLQ has messages (failed runner spawns)"

  dimensions = {
    QueueName = aws_sqs_queue.jobs_dlq.name
  }

  tags = merge(local.common_tags, {
    Module = "github-runners"
  })
}
