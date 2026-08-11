output "lambda_functions" {
  description = "Lambdas criadas"

  value = [
    for lambda in aws_lambda_function.lambda :
    {
      name          = lambda.function_name
      arn           = lambda.arn
      architecture  = lambda.architectures[0]
      memory        = lambda.memory_size
    }
  ]
}