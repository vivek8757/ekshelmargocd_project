# Security Group for VPC Link
resource "aws_security_group" "vpc_link" {
  name        = "${var.cluster_name}-vpc-link-sg"
  description = "Security group for API Gateway VPC Link"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-vpc-link-sg"
  }
}

# AWS API Gateway HTTP API
resource "aws_apigatewayv2_api" "http_api" {
  name          = "${var.cluster_name}-gateway"
  protocol_type = "HTTP"
  description   = "API Gateway for EKS microservices demo application"
}

# VPC Link to connect API Gateway to the EKS private subnets
resource "aws_apigatewayv2_vpc_link" "eks" {
  name               = "${var.cluster_name}-vpc-link"
  security_group_ids = [aws_security_group.vpc_link.id]
  subnet_ids         = aws_subnet.private[*].id

  tags = {
    Name = "${var.cluster_name}-vpc-link"
  }
}

# API Gateway Integration (Proxy route to EKS Private NLB)
# Note: The URI will point to the private NLB created by the Nginx Ingress controller.
# Since the NLB is managed by Kubernetes, we template the integration to point to
# a variable or a placeholder, which the user can bind after deploying the NLB service in EKS.
resource "aws_apigatewayv2_integration" "eks_integration" {
  count              = var.enable_api_gateway_integration ? 1 : 0
  api_id             = aws_apigatewayv2_api.http_api.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.eks.id

  # Placeholder URI: usually http://<private-nlb-dns-name>
  # In actual deployment, this points to the private DNS of the NLB created by Nginx Ingress
  integration_uri = "http://internal-eks-demo-nlb.us-east-1.elb.amazonaws.com"

  description = "Integration forwarding all traffic to private EKS Ingress Controller"
}

# Catch-All Route (Forward everything to EKS)
resource "aws_apigatewayv2_route" "default_route" {
  count     = var.enable_api_gateway_integration ? 1 : 0
  api_id    = aws_apigatewayv2_api.http_api.id
  route_key = "ANY /{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.eks_integration[0].id}"
}

# Deploy the HTTP API
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.http_api.id
  name        = "$default"
  auto_deploy = true
}
