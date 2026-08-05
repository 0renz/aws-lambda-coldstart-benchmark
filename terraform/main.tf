# Empacota o código da Lambda (pasta src/) em um .zip automaticamente
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "../${path.module}/src"
  output_path = "../${path.module}/build/lambda.zip"
}

# IAM Role que a Lambda vai assumir
resource "aws_iam_role" "lambda_role" {
  name = "${var.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Environment = var.environment
  }
}

# Policy básica: permissão para escrever logs no CloudWatch
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Função Lambda
resource "aws_lambda_function" "hello_world" {
  function_name = var.function_name
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.handler"
  runtime       = var.runtime

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  timeout     = 10                  # Tempo limite de execução em segundos
  memory_size = 512                 # Tamanho da memória em MB
  architectures = ["x86_64"]        # Arquitetura da função (x86_64 ou arm64)

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  tags = {
    Environment = var.environment
  }
}

# Log group explícito (evita criação implícita sem controle de retenção)
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = 14
}
