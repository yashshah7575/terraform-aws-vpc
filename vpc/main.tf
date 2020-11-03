data "aws_availability_zones" "az" {}
data "aws_vpc" "default_vpc" {}
data "aws_region" "current_region" {}

locals {
  azids_by_region = {
    "us-east-1" = ["use1-az1", "use1-az2", "use1-az3"]
    "us-east-2" = ["use2-az1", "use2-az2", "use2-az3"]
    "us-west-2" = ["usw2-az1", "usw2-az2", "usw2-az3"]
    "ca-central-1" = ["cac1-az1", "cac1-az2", "cac1-az4"]
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
  tags = {
    Name = "${var.name}-${var.environment}"
  }
}

resource "aws_subnet" "public_subnet" {
 for_each             = local.az_map
  cidr_block           = cidrsubnet(data.aws_vpc.default_vpc.cidr_block, local.add_bits, each.key + 5)
  availability_zone_id = each.value
  vpc_id               = data.aws_vpc.default_vpc.id
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.name}-${var.environment}"
  }
}

# Internate Gateway for the public subnet
resource "aws_internet_gateway" "gw" {
  vpc_id = data.aws_vpc.default_vpc.id
  tags = {
    Name = "${var.name}-${var.environment}"
  }
}


# Route the public subnet traffic through the internet gateway
resource "aws_route" "internet_access" {
  route_table_id         = data.aws_vpc.default_vpc.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

# Create a NAT gateway with an EIP for each private subnet to get internet connectivity
resource "aws_eip" "eip" {
  vpc        = true
  depends_on = [aws_internet_gateway.gw]
  tags = {
    Name        = "${var.name}-${var.environment}"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  for_each = local.az_map
  subnet_id = aws_subnet.public_subnet[each.key].id
  allocation_id = aws_eip.eip.id
  depends_on    = [aws_internet_gateway.gw]
  tags = {
    Name        = "${var.name}-${var.environment}"
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = data.aws_vpc.default_vpc.id
}

resource "aws_route_table" "public_rt" {
  vpc_id = data.aws_vpc.default_vpc.id
}

# Explicitely associate the newly created route tables to the private subnets (so they don't default to the main route table)
resource "aws_route_table_association" "private_rt_asso" {
  for_each = local.az_map
  route_table_id = aws_route_table.private_rt.id
  subnet_id = aws_subnet.private_subnet[each.key].id
}

resource "aws_route_table_association" "public_rt_asso" {
  for_each = local.az_map
  route_table_id = aws_route_table.public_rt.id
  subnet_id = aws_subnet.public_subnet[each.key].id
}

#VPC module output
output "vpc_id" {
  value = data.aws_vpc.default_vpc.id
}