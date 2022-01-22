terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.73.0"
    }
  }
}

provider "aws" {
  region     = "us-east-1"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

locals {
  project_name    = "sa-practice"
  vpc_cidr        = "10.0.1.0/24"
  private_subnets = ["10.0.1.0/26", "10.0.1.64/26"]
  public_subnets  = ["10.0.1.128/26", "10.0.1.192/26"]
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

resource "aws_vpc" "main" {
  cidr_block = local.vpc_cidr

  tags = {
    Name = local.project_name
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "privates" {
  count             = length(local.private_subnets)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnets[count.index]

  tags = {
    Name = "${local.project_name}-private-${count.index}"
  }
}

resource "aws_subnet" "publics" {
  count             = length(local.public_subnets)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.public_subnets[count.index]

  tags = {
    Name = "${local.project_name}-public-${count.index}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.project_name}-public"
  }
}

resource "aws_default_route_table" "publics" {
  default_route_table_id = aws_vpc.main.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${local.project_name}-public"
  }
}

resource "aws_eip" "nat" {
  vpc = true
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.publics[0].id

  tags = {
    Name = "${local.project_name}-nat-gw"
  }
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${local.project_name}-private"
  }
}

resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
}

resource "aws_vpc_endpoint_route_table_association" "private_s3_vpc_endpoint" {
  route_table_id  = aws_route_table.private.id
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.privates)
  subnet_id      = aws_subnet.privates[count.index].id
  route_table_id = aws_route_table.private.id
}
