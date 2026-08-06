# ============================================================
# DocumentDB VPC (separate, same region, peered to main VPC)
# ============================================================

variable "docdb_vpc_cidr" {
  description = "CIDR block for the DocumentDB VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "docdb_master_username" {
  description = "Master username for DocumentDB cluster"
  type        = string
  default     = "docdbadmin"
}

variable "docdb_master_password" {
  description = "Master password for DocumentDB cluster"
  type        = string
  sensitive   = true
}

resource "aws_vpc" "docdb" {
  cidr_block           = var.docdb_vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.cluster_name}-docdb-vpc"
  }
}

resource "aws_subnet" "docdb_private" {
  count             = 2
  vpc_id            = aws_vpc.docdb.id
  cidr_block        = cidrsubnet(var.docdb_vpc_cidr, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.cluster_name}-docdb-private-${data.aws_availability_zones.available.names[count.index]}"
  }
}

resource "aws_route_table" "docdb_private" {
  vpc_id = aws_vpc.docdb.id

  tags = {
    Name = "${var.cluster_name}-docdb-private-rt"
  }
}

resource "aws_route_table_association" "docdb_private" {
  count          = 2
  subnet_id      = aws_subnet.docdb_private[count.index].id
  route_table_id = aws_route_table.docdb_private.id
}

# ============================================================
# VPC Peering: main EKS VPC <-> DocumentDB VPC (same account/region)
# ============================================================

resource "aws_vpc_peering_connection" "eks_to_docdb" {
  vpc_id      = aws_vpc.main.id
  peer_vpc_id = aws_vpc.docdb.id
  auto_accept = true

  tags = {
    Name = "${var.cluster_name}-eks-to-docdb-peering"
  }
}

# Route from EKS private subnets -> DocumentDB VPC
resource "aws_route" "eks_to_docdb" {
  route_table_id            = aws_route_table.private.id
  destination_cidr_block    = var.docdb_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.eks_to_docdb.id
}

# Route from DocumentDB VPC -> EKS VPC
resource "aws_route" "docdb_to_eks" {
  route_table_id            = aws_route_table.docdb_private.id
  destination_cidr_block    = var.vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.eks_to_docdb.id
}

# ============================================================
# DocumentDB Security Group - only allow EKS VPC CIDR on 27017
# ============================================================

resource "aws_security_group" "docdb" {
  name        = "${var.cluster_name}-docdb-sg"
  description = "Allow MongoDB wire protocol access from EKS VPC only"
  vpc_id      = aws_vpc.docdb.id

  ingress {
    description = "MongoDB protocol from EKS VPC"
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-docdb-sg"
  }
}

# ============================================================
# DocumentDB Subnet Group + Cluster
# ============================================================

resource "aws_docdb_subnet_group" "main" {
  name       = "${var.cluster_name}-docdb-subnet-group"
  subnet_ids = aws_subnet.docdb_private[*].id

  tags = {
    Name = "${var.cluster_name}-docdb-subnet-group"
  }
}

resource "aws_docdb_cluster" "main" {
  cluster_identifier     = "${var.cluster_name}-docdb"
  engine                 = "docdb"
  master_username        = var.docdb_master_username
  master_password        = var.docdb_master_password
  db_subnet_group_name   = aws_docdb_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.docdb.id]
  skip_final_snapshot    = true
  storage_encrypted      = true
  deletion_protection    = false

  tags = {
    Name = "${var.cluster_name}-docdb-cluster"
  }
}

resource "aws_docdb_cluster_instance" "main" {
  identifier         = "${var.cluster_name}-docdb-instance-1"
  cluster_identifier = aws_docdb_cluster.main.id
  instance_class     = "db.t3.medium"

  tags = {
    Name = "${var.cluster_name}-docdb-instance-1"
  }
}

# ============================================================
# Outputs
# ============================================================

output "docdb_cluster_endpoint" {
  description = "DocumentDB cluster connection endpoint"
  value       = aws_docdb_cluster.main.endpoint
}

output "docdb_cluster_port" {
  description = "DocumentDB cluster port"
  value       = aws_docdb_cluster.main.port
}

output "docdb_vpc_id" {
  description = "DocumentDB VPC ID"
  value       = aws_vpc.docdb.id
}