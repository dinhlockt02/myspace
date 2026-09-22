terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "local" {}
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "idea-collector"
      Environment = "prod"
      ManagedBy   = "terraform"
    }
  }
}

module "lambda" {
  source             = "../../modules/lambda"
  project_name       = var.project_name
  environment        = "prod"
  lambda_binary_path = var.lambda_binary_path
  timeout            = 30
  memory_size        = 256
}

module "api_gateway" {
  source               = "../../modules/api-gateway"
  project_name         = var.project_name
  environment          = "prod"
  lambda_function_name = module.lambda.function_name
  lambda_invoke_arn    = module.lambda.invoke_arn
  cors_origins         = var.cors_origins
}
