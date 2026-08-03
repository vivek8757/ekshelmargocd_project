# S3 Bucket for demo uploads
resource "aws_s3_bucket" "uploads" {
  bucket_prefix = "eks-demo-uploads-"
  force_destroy = true # Allow clean deletion for demo purposes

  tags = {
    Name = "eks-demo-uploads-bucket"
  }
}

# Block all public access - bucket is private
resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IAM Policy for Backend S3 Access
resource "aws_iam_policy" "backend_s3" {
  name        = "${var.cluster_name}-backend-s3-policy"
  description = "Allows the EKS backend service to write to the uploads S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.uploads.arn,
          "${aws_s3_bucket.uploads.arn}/*"
        ]
      }
    ]
  })
}

# IAM Role for Backend Service Account (IRSA)
resource "aws_iam_role" "backend_s3" {
  name = "${var.cluster_name}-backend-s3-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Condition = {
          StringEquals = {
            # In EKS, the token is verified against the backend OIDC provider issuer URL.
            # Only match the backend ServiceAccount in the default namespace.
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:default:backend-s3-sa"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "backend_s3" {
  policy_arn = aws_iam_policy.backend_s3.arn
  role       = aws_iam_role.backend_s3.name
}

output "s3_bucket_name" {
  description = "Dynamically generated S3 bucket name"
  value       = aws_s3_bucket.uploads.id
}

output "backend_s3_role_arn" {
  description = "ARN of the IAM Role for backend S3 service account"
  value       = aws_iam_role.backend_s3.arn
}
