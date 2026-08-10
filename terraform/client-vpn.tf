# ============================================================
# AWS Client VPN — private access to EKS API (kubectl over VPN)
# ============================================================

variable "vpn_client_cidr" {
  description = "CIDR block for VPN client IP assignment (must not overlap VPC CIDRs)"
  type        = string
  default     = "10.2.0.0/22"
}

variable "vpn_server_certificate_arn" {
  description = "ACM ARN of the Client VPN server certificate"
  type        = string
}

variable "vpn_client_root_certificate_arn" {
  description = "ACM ARN of the CA certificate used to validate client certificates"
  type        = string
}

resource "aws_security_group" "client_vpn" {
  name        = "${var.cluster_name}-client-vpn-sg"
  description = "Security group for Client VPN endpoint"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow VPN clients to reach EKS API and cluster resources"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-client-vpn-sg"
  }
}

resource "aws_cloudwatch_log_group" "client_vpn" {
  name              = "/aws/clientvpn/${var.cluster_name}"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_stream" "client_vpn" {
  name           = "connection-log"
  log_group_name = aws_cloudwatch_log_group.client_vpn.name
}

resource "aws_ec2_client_vpn_endpoint" "main" {
  description            = "${var.cluster_name}-client-vpn"
  server_certificate_arn = var.vpn_server_certificate_arn
  client_cidr_block      = var.vpn_client_cidr
  split_tunnel           = true
  vpc_id                 = aws_vpc.main.id
  security_group_ids     = [aws_security_group.client_vpn.id]

  authentication_options {
    type                       = "certificate-authentication"
    root_certificate_chain_arn = var.vpn_client_root_certificate_arn
  }

  connection_log_options {
    enabled               = true
    cloudwatch_log_group  = aws_cloudwatch_log_group.client_vpn.name
    cloudwatch_log_stream = aws_cloudwatch_log_stream.client_vpn.name
  }

  tags = {
    Name = "${var.cluster_name}-client-vpn"
  }
}

resource "aws_ec2_client_vpn_network_association" "private" {
  count                  = 2
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  subnet_id              = aws_subnet.private[count.index].id
}

resource "aws_ec2_client_vpn_authorization_rule" "main" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  target_network_cidr    = var.vpc_cidr
  authorize_all_groups   = true
}

resource "aws_ec2_client_vpn_route" "private" {
  count                  = 2
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.main.id
  destination_cidr_block = var.vpc_cidr
  target_vpc_subnet_id   = aws_subnet.private[count.index].id
   description             = "Default Route"

  depends_on = [aws_ec2_client_vpn_network_association.private]
}

output "client_vpn_endpoint_id" {
  description = "Client VPN Endpoint ID"
  value       = aws_ec2_client_vpn_endpoint.main.id
}
