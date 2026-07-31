data "aws_availability_zones" "available" {
  state = "available"
}

# VPC Definition
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name                                      = "${var.cluster_name}-vpc"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

# Public Subnets (For Load Balancers, API Gateway endpoints, NAT Gateway)
resource "aws_subnet" "public" {
  count                   = 3
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                      = "${var.cluster_name}-public-${data.aws_availability_zones.available.names[count.index]}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                  = "1"
  }
}

# Private Subnets (For EKS Nodes & Private endpoints)
resource "aws_subnet" "private" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name                                      = "${var.cluster_name}-private-${data.aws_availability_zones.available.names[count.index]}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"         = "1"
    # Karpenter subnet discovery tag
    "karpenter.sh/discovery"                  = var.cluster_name
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.cluster_name}-igw"
  }
}

# NAT Gateway IP & resource (We use 1 NAT Gateway to reduce cost, but 3 can be used for HA)
resource "aws_eip" "nat" {
  domain = "vpc"
  tags = {
    Name = "${var.cluster_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.cluster_name}-nat-gw"
  }

  depends_on = [aws_internet_gateway.igw]
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.cluster_name}-public-rt"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }

  tags = {
    Name = "${var.cluster_name}-private-rt"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = 3
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# --- VPC ENDPOINT FOR S3 ---
# Gateway Endpoint allows EKS nodes to write to S3 without passing NAT gateway
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id, aws_route_table.public.id]

  tags = {
    Name = "${var.cluster_name}-s3-endpoint"
  }
}

# --- VPC PEERING TO MONGODB ATLAS ---
# Requests connection to MongoDB Atlas cluster VPC
resource "aws_vpc_peering_connection" "atlas" {
  count         = var.enable_vpc_peering ? 1 : 0
  peer_owner_id = var.mongodb_atlas_aws_account_id
  peer_vpc_id   = var.mongodb_atlas_vpc_id
  vpc_id        = aws_vpc.main.id
  peer_region   = lower(replace(var.mongodb_atlas_region, "_", "-"))
  auto_accept   = false # AWS side cannot auto-accept across accounts, Atlas side accepts it

  tags = {
    Name = "${var.cluster_name}-peering-to-atlas"
  }
}

# Route EKS Private Subnet traffic destined for MongoDB Atlas over Peering Connection
resource "aws_route" "peering_route" {
  count                     = var.enable_vpc_peering ? 1 : 0
  route_table_id            = aws_route_table.private.id
  destination_cidr_block     = var.mongodb_atlas_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.atlas[0].id
}
