output "function_arn" {
  value       = aws_lambda_function.handler.arn
  description = "Lambda function ARN"
}

output "function_name" {
  value       = aws_lambda_function.handler.function_name
  description = "Lambda function name"
}

output "invoke_arn" {
  value       = aws_lambda_function.handler.invoke_arn
  description = "Lambda invoke ARN for API Gateway"
}
