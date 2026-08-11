variable "aws_region" {
  description = "Região da AWS onde os recursos serão criados"
  type        = string
  default     = "us-east-1"
}

variable "function_name" {
  description = "Nome da função Lambda"
  type        = string
  default     = "hello-world-lambda"
}

variable "runtime" {
  description = "Runtime da Lambda"
  type        = string
  default     = "python3.12"
}

variable "environment" {
  description = "Tag de ambiente (dev, hml, prod)"
  type        = string
  default     = "dev"
}

############

variable "lambda_memory_size" {
  description = "Tamanho da memória da função Lambda em MB (128, 256, 512, 1024, 2048, 3008)"
  type        = number
  default     = 2048
}

variable "lambda_architecture" {
  description = "Arquitetura da função Lambda (x86_64 ou arm64)"
  type        = string
  default     = "arm64"
}

variable "lambda_count" {
  description = "Quantidade de Lambdas a serem criadas"
  type        = number
  default     = 1

  validation {
    condition     = var.lambda_count >= 1
    error_message = "A quantidade de Lambdas deve ser maior ou igual a 1."
  }
}