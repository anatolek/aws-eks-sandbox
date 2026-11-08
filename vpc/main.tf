terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

locals {
  nat_gateway_count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : 2) : 0
  common_tags       = merge(var.additional_tags, { ManagedBy = "Terraform" })
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-vpc"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-igw"
  })
}

resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.this.id
  availability_zone       = var.availability_zones[count.index]
  cidr_block              = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = var.map_public_ip_on_launch

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-public-${count.index + 1}"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  count = 2

  vpc_id            = aws_vpc.this.id
  availability_zone = var.availability_zones[count.index]
  cidr_block        = var.private_subnet_cidrs[count.index]

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-private-${count.index + 1}"
    Tier = "private"
  })
}

resource "aws_subnet" "rds" {
  count = 2

  vpc_id            = aws_vpc.this.id
  availability_zone = var.availability_zones[count.index]
  cidr_block        = var.rds_subnet_cidrs[count.index]

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-rds-${count.index + 1}"
    Tier = "rds"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count = 2

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_eip" "nat" {
  count = local.nat_gateway_count

  domain = "vpc"

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-nat-eip-${count.index + 1}"
  })
}

resource "aws_nat_gateway" "this" {
  count = local.nat_gateway_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[var.single_nat_gateway ? 0 : count.index].id

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-nat-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "private" {
  count = 2

  vpc_id = aws_vpc.this.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []

    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.this[var.single_nat_gateway ? 0 : count.index].id
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-private-rt-${count.index + 1}"
  })
}

resource "aws_route_table_association" "private" {
  count = 2

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route_table" "rds" {
  count = 2

  vpc_id = aws_vpc.this.id

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-rds-rt-${count.index + 1}"
  })
}

resource "aws_route_table_association" "rds" {
  count = 2

  subnet_id      = aws_subnet.rds[count.index].id
  route_table_id = aws_route_table.rds[count.index].id
}

resource "aws_db_subnet_group" "this" {
  name        = "${var.name_prefix}-rds-subnet-group"
  description = "RDS subnet group for ${var.name_prefix}"
  subnet_ids  = aws_subnet.rds[*].id

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-rds-subnet-group"
  })
}

output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "rds_subnet_ids" {
  value = aws_subnet.rds[*].id
}

output "rds_subnet_group_name" {
  value = aws_db_subnet_group.this.name
}
