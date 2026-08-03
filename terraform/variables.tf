variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "eks-demo-cluster"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "domain_name" {
  description = "Root domain name (existing Route53 hosted zone)"
  type        = string
  default     = "vivekkumarsingh.online"
}

variable "subdomain" {
  description = "Subdomain used for the EKS demo application"
  type        = string
  default     = "demoeks.vivekkumarsingh.online"
}

variable "enable_vpc_peering" {
  description = "Flag to enable VPC peering with MongoDB Atlas. Requires valid account and VPC IDs."
  type        = bool
  default     = false
}

variable "enable_api_gateway_integration" {
  description = "Flag to enable API Gateway routes and integrations. Requires valid NLB Listener ARN."
  type        = bool
  default     = false
}

# MongoDB Atlas Peering parameters (Placeholders for User input)
variable "mongodb_atlas_aws_account_id" {
  description = "AWS account ID of the MongoDB Atlas connection (retrieved from Atlas console)"
  type        = string
  default     = "345678901234" # Placeholder
}

variable "mongodb_atlas_vpc_id" {
  description = "VPC ID of the MongoDB Atlas cluster"
  type        = string
  default     = "vpc-0abcde123456" # Placeholder
}

variable "mongodb_atlas_vpc_cidr" {
  description = "CIDR block of the MongoDB Atlas cluster VPC"
  type        = string
  default     = "192.168.0.0/21" # Default Atlas CIDR
}

variable "mongodb_atlas_region" {
  description = "AWS Region of the MongoDB Atlas cluster VPC"
  type        = string
  default     = "US_EAST_1"
}
