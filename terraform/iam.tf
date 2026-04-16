data "aws_caller_identity" "current" {}

# -----------------------------------------------------------------------
# EC2 Instance Profile for MongoDB VM
# INTENTIONAL WEAKNESS: Overly permissive — allows creating EC2 instances
# -----------------------------------------------------------------------
resource "aws_iam_role" "mongodb_ec2" {
  name = "wiz-exercise-mongodb-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# INTENTIONAL WEAKNESS: ec2:* allows creating, modifying, and terminating VMs
resource "aws_iam_role_policy" "mongodb_ec2_overpermissive" {
  name = "wiz-exercise-mongodb-overpermissive"
  role = aws_iam_role.mongodb_ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "OverlyPermissiveEC2Access"
        Effect   = "Allow"
        Action   = "ec2:*"
        Resource = "*"
      },
      {
        Sid    = "S3BackupAccess"
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.mongodb_backup.arn,
          "${aws_s3_bucket.mongodb_backup.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "mongodb_ec2" {
  name = "wiz-exercise-mongodb-ec2-profile"
  role = aws_iam_role.mongodb_ec2.name
}

# Note: EKS node group IAM role is created by the terraform-aws-modules/eks module.
# The module automatically attaches AmazonEKSWorkerNodePolicy, AmazonEKS_CNI_Policy,
# and AmazonEC2ContainerRegistryReadOnly to the node group role.
