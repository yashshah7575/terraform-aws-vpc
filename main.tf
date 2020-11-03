provider "aws" {
  region     = var.aws_region
}

module "vpc" {
  source             = "./vpc"
  name = var.name
  environment = var.environment
  subnet_count = var.subnet_count
  subnet_cidr_size = var.subnet_cidr_size
}