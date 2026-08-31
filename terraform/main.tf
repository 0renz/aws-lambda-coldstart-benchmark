# Empacota o código da Lambda
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "../${path.module}/src"
  output_path = "../${path.module}/build/lambda.zip"
}

# IAM Role
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

# Permissão básica para CloudWatch Logs
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambdas
resource "aws_lambda_function" "lambda" {

  count = var.lambda_count

  function_name = format(
    "%s-%02d-%s-%dmb",
    var.function_name,
    count.index + 1,
    var.lambda_architecture == "x86_64" ? "x86" : "arm",
    var.lambda_memory_size
  )

  role    = aws_iam_role.lambda_role.arn
  handler = "index.lambda_handler"
  runtime = var.runtime

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  timeout     = 10
  memory_size = var.lambda_memory_size

  architectures = [
    var.lambda_architecture
  ]

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  tags = {
    Environment = var.environment
    LambdaIndex = tostring(count.index + 1)
    Architecture = var.lambda_architecture
    Memory       = "${var.lambda_memory_size}MB"
  }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "lambda_logs" {

  count = var.lambda_count

  name = "/aws/lambda/${aws_lambda_function.lambda[count.index].function_name}"

  retention_in_days = 14
}