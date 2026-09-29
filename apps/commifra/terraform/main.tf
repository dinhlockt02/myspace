terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "myspace"
      App       = "commifra"
      ManagedBy = "terraform"
    }
  }
}

module "vpc" {
  source = "./modules/vpc"

  cidr         = var.vpc_cidr
  azs          = var.vpc_azs
  project_name = "commifra"
}

module "oidc" {
  source = "./modules/oidc"

  github_org           = var.github_owner
  github_repo          = var.github_repo
  allowed_environments = var.allowed_environments
}

module "github_runners" {
  source = "./modules/github-runners"

  github_owner        = var.github_owner
  github_repo         = var.github_repo
  github_pat          = var.github_pat
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.public_subnet_ids
  oidc_provider_arn   = module.oidc.provider_arn
  runner_labels       = ["self-hosted", "linux", "x64"]
  instance_types      = var.runner_instance_types
  runner_architecture = "x86_64"
  max_count           = var.runner_max_count
}

module "route53" {
  source = "./modules/route53"

  count = var.domain_name != "" ? 1 : 0

  domain_name     = var.domain_name
}
