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
