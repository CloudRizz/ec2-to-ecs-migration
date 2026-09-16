# ---------------------------------------------------------------------------
# VPC
# ---------------------------------------------------------------------------
# Creates the shared VPC for the ECS platform with DNS support enabled.

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-vpc"
    }
  )
}


# ---------------------------------------------------------------------------
# Internet Gateway
# ---------------------------------------------------------------------------
# Provides internet connectivity for resources deployed in public subnets.

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-igw"
    }
  )
}


# ---------------------------------------------------------------------------
# Public Subnets
# ---------------------------------------------------------------------------
# Creates public subnets across multiple Availability Zones.
# These will host internet-facing resources such as the ALB and NAT Gateways.

resource "aws_subnet" "public" {
  for_each = var.public_subnets

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-public-${each.key}"
      Type = "Public"
    }
  )
}


# ---------------------------------------------------------------------------
# Private Subnets
# ---------------------------------------------------------------------------
# Creates private subnets across multiple Availability Zones.
# ECS Fargate tasks will run here without public IP addresses.

resource "aws_subnet" "private" {
  for_each = var.private_subnets

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-private-${each.key}"
      Type = "Private"
    }
  )
}


# ---------------------------------------------------------------------------
# Public Route Table
# ---------------------------------------------------------------------------
# Routes outbound internet traffic from public subnets through the
# Internet Gateway.

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-public-rt"
    }
  )
}


# ---------------------------------------------------------------------------
# Public Route Table Associations
# ---------------------------------------------------------------------------
# Associates every public subnet with the shared public route table.

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}


# ---------------------------------------------------------------------------
# NAT Gateway Elastic IPs
# ---------------------------------------------------------------------------
# Allocates one Elastic IP per Availability Zone for the NAT Gateways.

resource "aws_eip" "nat" {
  for_each = var.public_subnets

  domain = "vpc"

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-nat-eip-${each.key}"
    }
  )
}


# ---------------------------------------------------------------------------
# NAT Gateways
# ---------------------------------------------------------------------------
# Deploys one NAT Gateway per Availability Zone.
# This allows private ECS tasks to reach external AWS services and the
# internet without exposing the tasks directly to inbound internet traffic.

resource "aws_nat_gateway" "main" {
  for_each = var.public_subnets

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-nat-${each.key}"
    }
  )

  depends_on = [aws_internet_gateway.main]
}


# ---------------------------------------------------------------------------
# Private Route Tables
# ---------------------------------------------------------------------------
# Creates one private route table per Availability Zone.
# Each private subnet sends outbound traffic through the NAT Gateway located
# in the same Availability Zone, avoiding a single-AZ dependency.

resource "aws_route_table" "private" {
  for_each = var.private_subnets

  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[each.key].id
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.name_prefix}-private-rt-${each.key}"
    }
  )
}


# ---------------------------------------------------------------------------
# Private Route Table Associations
# ---------------------------------------------------------------------------
# Associates each private subnet with the private route table for its
# corresponding Availability Zone.

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}