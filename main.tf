provider "aws" {
  region     = var.aws_region
}

/*
module "vpc" {
  source             = "./vpc"
  name = var.name
  environment = var.environment
  subnet_count = var.subnet_count
  subnet_cidr_size = var.subnet_cidr_size
}

*/



data "aws_availability_zones" "az" {}
data "aws_vpc" "default_vpc" {}
data "aws_region" "current_region" {}

locals {
  azids_by_region = {
    "us-east-1" = ["use1-az1", "use1-az2", "use1-az3"]
    "us-east-2" = ["use2-az1", "use2-az2", "use2-az3"]
    "us-west-2" = ["usw2-az1", "usw2-az2", "usw2-az3"]
    #"ca-central-1" = ["cac1-az1", "cac1-az2", "cac1-az4"]
    "ap-south-1" = ["aps1-az1","aps1-az2","aps1-az3"]
  }

  cidr_maskbits = tonumber(split("/", data.aws_vpc.default_vpc.cidr_block)[1])
  subnet_max_index = (pow(2, var.subnet_cidr_size) / pow(2, local.cidr_maskbits)) - 1
  add_bits = var.subnet_cidr_size - local.cidr_maskbits
  network_indexes = range(0, var.subnet_count)
  az_map = { for i in local.network_indexes : i => element(local.azids_by_region[data.aws_region.current_region.name], i) } 
}

resource "aws_subnet" "private_subnet" {
  for_each             = local.az_map
  cidr_block           = cidrsubnet(data.aws_vpc.default_vpc.cidr_block, local.add_bits, each.key)
  availability_zone_id = each.value
  vpc_id               = data.aws_vpc.default_vpc.id
  map_public_ip_on_launch = false
  tags = {
    Name = "${var.name}-${var.environment}"
  }
}

resource "aws_s3_bucket" "manage-user-bucket" {
  bucket = "manage-user-bucket"
  acl    = "public-read"
  tags = {
    Name = "${var.name}-${var.environment}"
  }
}

resource "aws_vpc_endpoint" "s3_vpc_endpoint" {
  vpc_id            = data.aws_vpc.default_vpc.id
  service_name      = "com.amazonaws.${data.aws_region.current_region.name}.s3"
}

resource "aws_ec2_transit_gateway" "manage_user_transit_gateway" {
  description = "Transit gateway for managing user"
}

resource "aws_route_table" "rt"{
  vpc_id = data.aws_vpc.default_vpc.id
}

resource "aws_vpc_endpoint_route_table_association" "s3_association" {
  vpc_endpoint_id = aws_vpc_endpoint.s3_vpc_endpoint.id
  route_table_id  = aws_route_table.rt.id
}

resource "aws_ec2_transit_gateway_vpc_attachment" "attachement" {
  subnet_ids = values({ for i in range(0, length(aws_subnet.private_subnet)) : i => aws_subnet.private_subnet[i].id }) 
  transit_gateway_id = aws_ec2_transit_gateway.manage_user_transit_gateway.id
  vpc_id            = data.aws_vpc.default_vpc.id
  tags = {
        Name = "${var.name}-${var.environment}"
  }
}

resource "aws_route" "route" {
  route_table_id  = aws_route_table.rt.id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id = aws_ec2_transit_gateway_vpc_attachment.attachement.transit_gateway_id
}


#VPC module output
output "subnet_ids" {
  value = values({ for i in range(0, length(aws_subnet.private_subnet)) : i => aws_subnet.private_subnet[i].id }) 
}

output "vpc_id" {
  value = data.aws_vpc.default_vpc.id
}