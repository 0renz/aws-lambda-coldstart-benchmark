output "lambda_function_name" {
  description = "Nome da função Lambda criada"
  value       = aws_lambda_function.hello_world.function_name
}

output "lambda_function_arn" {
  description = "ARN da função Lambda"
  value       = aws_lambda_function.hello_world.arn
}

output "lambda_invoke_arn" {
  description = "ARN de invocação (útil para integrar com API Gateway)"
  value       = aws_lambda_function.hello_world.invoke_arn
}
